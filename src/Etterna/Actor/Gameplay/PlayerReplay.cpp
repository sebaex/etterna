#include "Etterna/Globals/global.h"
#include "Etterna/Models/Misc/PlayerAI.h"
#include "Etterna/Models/Misc/PlayerState.h"
#include "ArrowEffects.h"
#include "NoteField.h"
#include "Etterna/Models/Misc/AdjustSync.h"
#include "Etterna/Models/Misc/Game.h"
#include "Etterna/Models/NoteData/NoteDataWithScoring.h"
#include "Etterna/Models/ScoreKeepers/ScoreKeeperNormal.h"
#include "Etterna/Singletons/GameState.h"
#include "Etterna/Singletons/NoteSkinManager.h"
#include "Etterna/Singletons/StatsManager.h"
#include "Etterna/Singletons/ScreenManager.h"
#include "Etterna/Singletons/ThemeManager.h"
#include "Etterna/Models/Misc/ThemeMetric.h"
#include "RageUtil/Utils/RageUtil.h"
#include "PlayerReplay.h"

PlayerReplay::PlayerReplay(NoteData& nd, bool bVisibleParts)
  : Player(nd, bVisibleParts)
{
	// eh
}

PlayerReplay::~PlayerReplay()
{
	// dont have to do anything here
}

void
PlayerReplay::Init(const std::string& sType,
				   PlayerState* pPlayerState,
				   PlayerStageStats* pPlayerStageStats,
				   LifeMeter* pLM,
				   ScoreKeeper* pPrimaryScoreKeeper)
{
	Player::Init(
	  sType, pPlayerState, pPlayerStageStats, pLM, pPrimaryScoreKeeper);
	if (m_pPlayerStageStats)
		m_pPlayerStageStats->m_bDisqualified = true;
}

void
PlayerReplay::Load()
{
	Player::Load();

	// Set the exact tap map when loading replay
	PlayerAI::SetUpExactTapMap(m_Timing);
}

void
PlayerReplay::UpdateHoldNotes(int iSongRow,
							  float fDeltaTime,
							  vector<TrackRowTapNote>& vTN)
{
	Player::UpdateHoldNotes(iSongRow, fDeltaTime, vTN);
	ASSERT(!vTN.empty());

	int iStartRow = vTN[0].iRow;
	int iMaxEndRow = INT_MIN;
	int iFirstTrackWithMaxEndRow = -1;

	TapNoteSubType subType = TapNoteSubType_Invalid;
	FOREACH(TrackRowTapNote, vTN, trtn)
	{
		int iTrack = trtn->iTrack;
		ASSERT(iStartRow == trtn->iRow);
		TapNote& tn = *trtn->pTN;
		int iEndRow = iStartRow + tn.iDuration;
		if (subType == TapNoteSubType_Invalid)
			subType = tn.subType;

		/* All holds must be of the same subType because fLife is handled
		 * in different ways depending on the SubType. */
		ASSERT(tn.subType == subType);

		if (iEndRow > iMaxEndRow) {
			iMaxEndRow = iEndRow;
			iFirstTrackWithMaxEndRow = iTrack;
		}
	}

	ASSERT(iFirstTrackWithMaxEndRow != -1);

	FOREACH(TrackRowTapNote, vTN, trtn)
	{
		TapNote& tn = *trtn->pTN;

		// check from now until the head of the hold to see if it should die
		// possibly really bad, but we dont REALLY care that much about fps
		// in replays, right?
		bool holdDropped = false;
		for (int yeet = vTN[0].iRow; yeet <= iSongRow && !holdDropped; yeet++) {
			if (PlayerAI::DetermineIfHoldDropped(yeet, trtn->iTrack)) {
				holdDropped = true;
			}
		}

		if (holdDropped) // it should be dead
		{
			tn.HoldResult.bHeld = false;
			tn.HoldResult.bActive = false;
			tn.HoldResult.fLife = 0.f;
			tn.HoldResult.hns = HNS_LetGo;

			// score the dead hold
			if (COMBO_BREAK_ON_IMMEDIATE_HOLD_LET_GO)
				IncrementMissCombo();
			SetHoldJudgment(tn, iFirstTrackWithMaxEndRow, iSongRow);
			HandleHoldScore(tn);
			return;
		}
	}
}

void
PlayerReplay::UpdateHoldsAndRolls(
  float fDeltaTime,
  const std::chrono::steady_clock::time_point& now)
{
	const float fSongBeat = m_pPlayerState->m_Position.m_fSongBeat;
	const int iSongRow = BeatToNoteRow(fSongBeat);

	// Auto tap rolls
	for (int iTrack = 0; iTrack < m_NoteData.GetNumTracks(); ++iTrack) {
		int iHeadRow;
		if (!m_NoteData.IsHoldNoteAtRow(iTrack, iSongRow, &iHeadRow))
			iHeadRow = iSongRow;

		const TapNote& tn = m_NoteData.GetTapNote(iTrack, iHeadRow);
		if (tn.type != TapNoteType_HoldHead ||
			tn.subType != TapNoteSubType_Roll)
			continue;
		if (tn.HoldResult.hns != HNS_None)
			continue;
		if (tn.HoldResult.fLife >= 0.5f)
			continue;

		Step(iTrack, iHeadRow, now, true, false);
	}

	// HoldNotes logic
	{

		// Fast forward to the first that needs hold judging.
		{
			NoteData::all_tracks_iterator& iter = *m_pIterNeedsHoldJudging;
			while (!iter.IsAtEnd() && iter.Row() <= iSongRow &&
				   !NeedsHoldJudging(*iter))
				++iter;
		}

		vector<TrackRowTapNote> vHoldNotesToGradeTogether;
		int iRowOfLastHoldNote = -1;
		NoteData::all_tracks_iterator iter = *m_pIterNeedsHoldJudging; // copy
		for (; !iter.IsAtEnd() && iter.Row() <= iSongRow; ++iter) {
			TapNote& tn = *iter;
			if (tn.type != TapNoteType_HoldHead)
				continue;

			int iTrack = iter.Track();
			int iRow = iter.Row();
			TrackRowTapNote trtn = { iTrack, iRow, &tn };

			/* All holds must be of the same subType because fLife is handled
			 * in different ways depending on the SubType. Handle Rolls one at
			 * a time and don't mix with holds. */
			switch (tn.subType) {
				DEFAULT_FAIL(tn.subType);
				case TapNoteSubType_Hold:
					break;
				case TapNoteSubType_Roll: {
					vector<TrackRowTapNote> v;
					v.push_back(trtn);
					UpdateHoldNotes(iSongRow, fDeltaTime, v);
				}
					continue; // don't process this below
			}

			if (!vHoldNotesToGradeTogether.empty()) {
				// LOG->Trace( ssprintf("UpdateHoldNotes; %i != %i || !judge
				// holds on same row together",iRow,iRowOfLastHoldNote) );
				UpdateHoldNotes(
				  iSongRow, fDeltaTime, vHoldNotesToGradeTogether);
				vHoldNotesToGradeTogether.clear();
			}
			iRowOfLastHoldNote = iRow;
			vHoldNotesToGradeTogether.push_back(trtn);
		}

		if (!vHoldNotesToGradeTogether.empty()) {
			// LOG->Trace("UpdateHoldNotes since
			// !vHoldNotesToGradeTogether.empty()");
			UpdateHoldNotes(iSongRow, fDeltaTime, vHoldNotesToGradeTogether);
			vHoldNotesToGradeTogether.clear();
		}
	}
}

void
PlayerReplay::Update(float fDeltaTime)
{
	const auto now = std::chrono::steady_clock::now();
	if (!m_bLoaded || GAMESTATE->m_pCurSong == NULL)
		return;

	ActorFrame::Update(fDeltaTime);

	const float fSongBeat = m_pPlayerState->m_Position.m_fSongBeat;
	const int iSongRow = BeatToNoteRow(fSongBeat);

	ArrowEffects::SetCurrentOptions(
	  &m_pPlayerState->m_PlayerOptions.GetCurrent());

	UpdateVisibleParts();

	// Sure, why not?
	if (GAMESTATE->GetPaused())
		return;

	// Step with offsets if we have column data.
	if (PlayerAI::pScoreData->GetReplayType() == 2) {
		if (PlayerAI::TapExistsAtOrBeforeThisRow(iSongRow)) {
			vector<TapReplayResult> trrVector =
			  PlayerAI::GetTapsAtOrBeforeRow(iSongRow);
			for (TapReplayResult& trr : trrVector) {
				// LOG->Trace("\tPassing row %d pressed on %d", iSongRow,
				// trr.row);
				Step(trr.track, trr.row, now, false, false, 0.f, trr.row);
			}
		}
	}

	// Replays dont care about player input: dont run this
	// UpdatePressedFlags();

	// Tell Rolls to update (if in Autoplay)
	// Tell Holds to update (lose life)
	UpdateHoldsAndRolls(fDeltaTime, now);

	// A lot of logic... basically everything not listed here
	UpdateCrossedRows(now);

	// Check for completely judged rows.
	UpdateJudgedRows(fDeltaTime);
	UpdateTapNotesMissedOlderThan(GetMaxStepDistanceSeconds());
}

void
PlayerReplay::CrossedRows(int iLastRowCrossed,
						  const std::chrono::steady_clock::time_point& now)
{
	NoteData::all_tracks_iterator& iter = *m_pIterUncrossedRows;
	int iLastSeenRow = -1;
	for (; !iter.IsAtEnd() && iter.Row() <= iLastRowCrossed; ++iter) {
		// Apply InitialHoldLife.
		TapNote& tn = *iter;
		int iRow = iter.Row();
		int iTrack = iter.Track();
		switch (tn.type) {
			case TapNoteType_HoldHead: {
				tn.HoldResult.fLife = 1;
				break;
			}
			default:
				break;
		}

		// Press Taps for Replays that have no column data
		if (tn.type != TapNoteType_Empty && tn.type != TapNoteType_Fake &&
			tn.type != TapNoteType_AutoKeysound && tn.result.tns == TNS_None &&
			this->m_Timing->IsJudgableAtRow(iRow)) {
			if (PlayerAI::GetReplayType() != 2) {
				Step(iTrack, iRow, now, false, false);
			}
		}

		// TODO: Can we remove the iLastSeenRow logic and the
		// autokeysound for loop, since the iterator in this loop will
		// already be iterating over all of the tracks?
		if (iRow != iLastSeenRow) {
			// crossed a new not-empty row
			iLastSeenRow = iRow;

			for (int t = 0; t < m_NoteData.GetNumTracks(); ++t) {
				const TapNote& tap = m_NoteData.GetTapNote(t, iRow);
				if (tap.type == TapNoteType_AutoKeysound) {
					PlayKeysound(tap, TNS_None);
				}
			}
		}
	}

	m_iFirstUncrossedRow = iLastRowCrossed + 1;
}

void
PlayerReplay::HandleTapRowScore(unsigned row)
{

	TapNoteScore scoreOfLastTap =
	  NoteDataWithScoring::LastTapNoteWithResult(m_NoteData, row).result.tns;
	const unsigned int iOldCombo =
	  m_pPlayerStageStats != nullptr ? m_pPlayerStageStats->m_iCurCombo : 0;
	const unsigned int iOldMissCombo =
	  m_pPlayerStageStats != nullptr ? m_pPlayerStageStats->m_iCurMissCombo : 0;

	if (scoreOfLastTap == TNS_Miss)
		m_LastTapNoteScore = TNS_Miss;

	for (int track = 0; track < m_NoteData.GetNumTracks(); ++track) {
		const TapNote& tn = m_NoteData.GetTapNote(track, row);
		// Mines cannot be handled here.
		if (tn.type == TapNoteType_Empty || tn.type == TapNoteType_Fake ||
			tn.type == TapNoteType_Mine || tn.type == TapNoteType_AutoKeysound)
			continue;
		if (m_pPrimaryScoreKeeper != nullptr && false)
			m_pPrimaryScoreKeeper->HandleTapScore(tn);
	}

	if (m_pPrimaryScoreKeeper != NULL)
		m_pPrimaryScoreKeeper->HandleTapRowScore(m_NoteData, row);

	const unsigned int iCurCombo =
	  m_pPlayerStageStats != nullptr ? m_pPlayerStageStats->m_iCurCombo : 0;
	const unsigned int iCurMissCombo =
	  m_pPlayerStageStats != nullptr ? m_pPlayerStageStats->m_iCurMissCombo : 0;

	SendComboMessages(iOldCombo, iOldMissCombo);

	if (m_pPlayerStageStats != nullptr) {
		SetCombo(iCurCombo, iCurMissCombo);
	}

	// mostly dead code for announcers and other stuff...
#define CROSSED(x) (iOldCombo < (x) && iCurCombo >= (x))
	if (CROSSED(100))
		SCREENMAN->PostMessageToTopScreen(SM_100Combo, 0);
	else if (CROSSED(200))
		SCREENMAN->PostMessageToTopScreen(SM_200Combo, 0);
	else if (CROSSED(300))
		SCREENMAN->PostMessageToTopScreen(SM_300Combo, 0);
	else if (CROSSED(400))
		SCREENMAN->PostMessageToTopScreen(SM_400Combo, 0);
	else if (CROSSED(500))
		SCREENMAN->PostMessageToTopScreen(SM_500Combo, 0);
	else if (CROSSED(600))
		SCREENMAN->PostMessageToTopScreen(SM_600Combo, 0);
	else if (CROSSED(700))
		SCREENMAN->PostMessageToTopScreen(SM_700Combo, 0);
	else if (CROSSED(800))
		SCREENMAN->PostMessageToTopScreen(SM_800Combo, 0);
	else if (CROSSED(900))
		SCREENMAN->PostMessageToTopScreen(SM_900Combo, 0);
	else if (CROSSED(1000))
		SCREENMAN->PostMessageToTopScreen(SM_1000Combo, 0);
	else if ((iOldCombo / 100) < (iCurCombo / 100) && iCurCombo > 1000)
		SCREENMAN->PostMessageToTopScreen(SM_ComboContinuing, 0);
#undef CROSSED

	// new max combo
	if (m_pPlayerStageStats)
		m_pPlayerStageStats->m_iMaxCombo =
		  max(m_pPlayerStageStats->m_iMaxCombo, iCurCombo);

	/* Use the real current beat, not the beat we've been passed. That's because
	 * we want to record the current life/combo to the current time; eg. if it's
	 * a MISS, the beat we're registering is in the past, but the life is
	 * changing now. We need to include time from previous songs in a course, so
	 * we can't use GAMESTATE->m_fMusicSeconds. Use fStepsSeconds instead. */
	if (m_pPlayerStageStats)
		m_pPlayerStageStats->UpdateComboList(
		  STATSMAN->m_CurStageStats.m_fStepsSeconds, false);

	ChangeLife(scoreOfLastTap);
}

void
PlayerReplay::UpdateTapNotesMissedOlderThan(float fMissIfOlderThanSeconds)
{
	int iMissIfOlderThanThisRow;
	const float fEarliestTime =
	  m_pPlayerState->m_Position.m_fMusicSeconds - fMissIfOlderThanSeconds;
	{
		TimingData::GetBeatArgs beat_info;
		beat_info.elapsed_time = fEarliestTime;
		m_Timing->GetBeatAndBPSFromElapsedTime(beat_info);

		iMissIfOlderThanThisRow = BeatToNoteRow(beat_info.beat);
		if (beat_info.freeze_out || beat_info.delay_out) {
			/* If there is a freeze on iMissIfOlderThanThisIndex, include this
			 * index too. Otherwise we won't show misses for tap notes on
			 * freezes until the freeze finishes. */
			if (!beat_info.delay_out)
				iMissIfOlderThanThisRow++;
		}
	}

	NoteData::all_tracks_iterator& iter = *m_pIterNeedsTapJudging;

	for (; !iter.IsAtEnd() && iter.Row() < iMissIfOlderThanThisRow; ++iter) {
		TapNote& tn = *iter;

		if (!NeedsTapJudging(tn))
			continue;

		// Ignore all notes in WarpSegments or FakeSegments.
		if (!m_Timing->IsJudgableAtRow(iter.Row()))
			continue;

		if (tn.type == TapNoteType_Mine) {
			tn.result.tns = TNS_AvoidMine;
			/* The only real way to tell if a mine has been scored is if it has
			 * disappeared but this only works for hit mines so update the
			 * scores for avoided mines here. */
			if (m_pPrimaryScoreKeeper)
				m_pPrimaryScoreKeeper->HandleTapScore(tn);
		} else {
			if ((PlayerAI::IsTapAtRowAndColumn(iter.Row(), iter.Track())))
				continue;

			tn.result.tns = TNS_Miss;

			if (GAMESTATE->CountNotesSeparately()) {
				SetJudgment(iter.Row(), iter.Track(), tn);
				HandleTapRowScore(iter.Row());
			}
		}
	}
}

void
PlayerReplay::Step(int col,
				   int row,
				   const std::chrono::steady_clock::time_point& tm,
				   bool bHeld,
				   bool bRelease,
				   float padStickSeconds,
				   int rowToJudge)
{
	// Do everything that depends on a timer here;
	// set your breakpoints somewhere after this block.
	std::chrono::duration<float> stepDelta =
	  std::chrono::steady_clock::now() - tm;
	float stepAgo = stepDelta.count() - padStickSeconds;

	const float fLastBeatUpdate =
	  m_pPlayerState->m_Position.m_LastBeatUpdate.Ago();
	const float fPositionSeconds =
	  m_pPlayerState->m_Position.m_fMusicSeconds - stepAgo;
	const float fTimeSinceStep = stepAgo;

	// LOG->Trace(ssprintf("col %d\n\trow %d", col, row));

	// idk if this is the correct value for input logs but we'll use them to
	// test -mina ok this is 100% not the place to do this
	// m_pPlayerStageStats->InputData.emplace_back(fPositionSeconds);

	float fSongBeat = m_pPlayerState->m_Position.m_fSongBeat;

	if (GAMESTATE->m_pCurSteps)
		fSongBeat = m_Timing->GetBeatFromElapsedTime(fPositionSeconds);

	const int iSongRow = row == -1 ? BeatToNoteRow(fSongBeat) : row;

	if (col != -1 && !bRelease) {
		// Update roll life
		// Let's not check the whole array every time.
		// Instead, only check 1 beat back.  Even 1 is overkill.
		// Just update the life here and let Update judge the roll.
		const int iStartCheckingAt = max(0, iSongRow - BeatToNoteRow(1));
		NoteData::TrackMap::iterator begin, end;
		m_NoteData.GetTapNoteRangeInclusive(
		  col, iStartCheckingAt, iSongRow + 1, begin, end);
		for (; begin != end; ++begin) {
			TapNote& tn = begin->second;
			if (tn.type != TapNoteType_HoldHead)
				continue;

			switch (tn.subType) {
				DEFAULT_FAIL(tn.subType);
				case TapNoteSubType_Hold:
					continue;
				case TapNoteSubType_Roll:
					break;
			}

			const int iRow = begin->first;

			HoldNoteScore hns = tn.HoldResult.hns;
			if (hns != HNS_None) // if this HoldNote already has a result
				continue; // we don't need to update the logic for this one

			// if they got a bad score or haven't stepped on the corresponding
			// tap yet
			const TapNoteScore tns = tn.result.tns;
			bool bInitiatedNote = true;
			bInitiatedNote =
			  tns != TNS_None && tns != TNS_Miss; // did they step on the start?
			const int iEndRow = iRow + tn.iDuration;

			if (bInitiatedNote && tn.HoldResult.fLife != 0) {
				/* This hold note is not judged and we stepped on its head.
				 * Update iLastHeldRow. Do this even if we're a little beyond
				 * the end of the hold note, to make sure iLastHeldRow is
				 * clamped to iEndRow if the hold note is held all the way. */
				// LOG->Trace("setting iLastHeldRow to min of iSongRow (%i) and
				// iEndRow (%i)",iSongRow,iEndRow);
				tn.HoldResult.iLastHeldRow = min(iSongRow, iEndRow);
			}

			// If the song beat is in the range of this hold:
			if (iRow <= iSongRow && iRow <= iEndRow) {
				if (bInitiatedNote) {
					// Increase life
					tn.HoldResult.fLife = 1;

					if (ROLL_BODY_INCREMENTS_COMBO) {
						IncrementCombo();

						bool bBright =
						  m_pPlayerStageStats &&
						  m_pPlayerStageStats->m_iCurCombo >
							(unsigned int)BRIGHT_GHOST_COMBO_THRESHOLD;
						if (m_pNoteField)
							m_pNoteField->DidHoldNote(col, HNS_Held, bBright);
					}
				}
				break;
			}
		}
	}

	// Check for tap
	int iStepSearchRows;
	static const float StepSearchDistance = GetMaxStepDistanceSeconds();
	int skipstart = nerv[10]; // this is not robust need to come up with
							  // something better later - Mina

	if (iSongRow < skipstart || iSongRow > static_cast<int>(nerv.size()) - 10) {
		iStepSearchRows =
		  max(BeatToNoteRow(m_Timing->GetBeatFromElapsedTime(
				m_pPlayerState->m_Position.m_fMusicSeconds +
				StepSearchDistance)) -
				iSongRow,
			  iSongRow - BeatToNoteRow(m_Timing->GetBeatFromElapsedTime(
						   m_pPlayerState->m_Position.m_fMusicSeconds -
						   StepSearchDistance))) +
		  ROWS_PER_BEAT;
	} else {
		/* Buncha bullshit that speeds up searching for the rows that we're
		concerned about judging taps within by avoiding the invocation of the
		incredibly slow getbeatfromelapsedtime. Needs to be cleaned up a lot,
		whole system does. Only in use if sequential assumption remains valid. -
		Mina */

		if (nerv[nervpos] < iSongRow && nervpos < nerv.size())
			nervpos += 1;

		size_t SearchIndexBehind = nervpos;
		size_t SearchIndexAhead = nervpos;
		float SearchBeginTime = m_Timing->WhereUAtBro(nerv[nervpos]);

		while (SearchIndexBehind > 1 &&
			   SearchBeginTime -
				   m_Timing->WhereUAtBro(nerv[SearchIndexBehind - 1]) <
				 StepSearchDistance)
			SearchIndexBehind -= 1;

		while (SearchIndexAhead > 1 && SearchIndexAhead + 1 > nerv.size() &&
			   m_Timing->WhereUAtBro(nerv[SearchIndexAhead + 1]) -
				   SearchBeginTime <
				 StepSearchDistance)
			SearchIndexAhead += 1;

		int MaxLookBehind = nerv[nervpos] - nerv[SearchIndexBehind];
		int MaxLookAhead = nerv[SearchIndexAhead] - nerv[nervpos];

		if (nervpos > 0)
			iStepSearchRows =
			  (max(MaxLookBehind, MaxLookAhead) + ROWS_PER_BEAT);
	}

	// calculate TapNoteScore
	TapNoteScore score = TNS_None;

	int iRowOfOverlappingNoteOrRow = row;
	if (row == -1 && col != -1)
		iRowOfOverlappingNoteOrRow = GetClosestNote(
		  col, iSongRow, iStepSearchRows, iStepSearchRows, false, false);

	if (iRowOfOverlappingNoteOrRow != -1 && col != -1) {
		// compute the score for this hit
		float fNoteOffset = 0.f;
		// we need this later if we are autosyncing
		const float fStepBeat = NoteRowToBeat(iRowOfOverlappingNoteOrRow);
		const float fStepSeconds = m_Timing->WhereUAtBro(fStepBeat);

		if (row == -1) {
			// We actually stepped on the note this long ago:
			// fTimeSinceStep

			/* GAMESTATE->m_fMusicSeconds is the music time as of
			 * GAMESTATE->m_LastBeatUpdate. Figure out what the music time is as
			 * of now. */
			const float fCurrentMusicSeconds =
			  m_pPlayerState->m_Position.m_fMusicSeconds +
			  (fLastBeatUpdate *
			   GAMESTATE->m_SongOptions.GetCurrent().m_fMusicRate);

			// ... which means it happened at this point in the music:
			const float fMusicSeconds =
			  fCurrentMusicSeconds -
			  fTimeSinceStep *
				GAMESTATE->m_SongOptions.GetCurrent().m_fMusicRate;

			// The offset from the actual step in seconds:
			fNoteOffset = (fStepSeconds - fMusicSeconds) /
						  GAMESTATE->m_SongOptions.GetCurrent()
							.m_fMusicRate; // account for music rate
		}

		NOTESKIN->SetLastSeenColor(
		  NoteTypeToString(GetNoteType(iRowOfOverlappingNoteOrRow)));

		const float fSecondsFromExact = fabsf(fNoteOffset);

		TapNote* pTN = nullptr;
		NoteData::iterator iter = m_NoteData.FindTapNote(
		  col,
		  GetClosestNote(col, iSongRow, MAX_NOTE_ROW, MAX_NOTE_ROW, false));

		pTN = &iter->second;

		// We don't really have to care if we are releasing on a non-lift,
		// right? This fixes a weird noteskin bug with tap explosions.
		if (PREFSMAN->m_bFullTapExplosions && bRelease &&
			pTN->type != TapNoteType_Lift)
			return;

		// Replays without column data dont use offset stuff
		// So we tell it to step NOW instead of at an offset
		// This undoes a hack, basically
		if (PlayerAI::GetReplayType() != 2)
			rowToJudge = iRowOfOverlappingNoteOrRow;

		// Score the Tap based on Replay Data
		if (bHeld) // a hack to make Rolls not do weird things like
				   // count as 0ms marvs.
		{
			score = TNS_None;
			fNoteOffset = -1.f;
		} else {
			if (PlayerAI::GetReplayType() == 2) {
				// iRowOfOverlappingNoteOrRow = rowToJudge;
			}
			fNoteOffset =
			  PlayerAI::GetTapNoteOffsetForReplay(pTN, rowToJudge, col);
			if (fNoteOffset == -2.f) // we hit a mine
			{
				score = TNS_HitMine;
				PlayerAI::RemoveTapFromVectors(rowToJudge, col);
			} else if (pTN->type == TapNoteType_Mine) // we are looking
													  // at a mine but
													  // missed it
			{
				return;
			} else // every other case
			{
				if (pTN->IsNote() || pTN->type == TapNoteType_Lift)
					score = PlayerAI::GetTapNoteScoreForReplay(m_pPlayerState,
															   fNoteOffset);
			}
		}

		// Do game-specific and mode-specific score mapping.
		score = GAMESTATE->GetCurrentGame()->MapTapNoteScore(score);
		if (score == TNS_W1 && !GAMESTATE->ShowW1())
			score = TNS_W2;

		if (score != TNS_None) {
			pTN->result.tns = score;
			pTN->result.fTapNoteOffset = -fNoteOffset;
		}

		m_LastTapNoteScore = score;
		if (pTN->result.tns != TNS_None)
			AddNoteToReplayData(GAMESTATE->CountNotesSeparately() ? col : -1,
								pTN,
								iRowOfOverlappingNoteOrRow);
		if (GAMESTATE->CountNotesSeparately()) {
			if (pTN->type != TapNoteType_Mine) {
				const bool bBlind =
				  (m_pPlayerState->m_PlayerOptions.GetCurrent().m_fBlind != 0);
				const bool bBright =
				  (m_pPlayerStageStats &&
				   m_pPlayerStageStats->m_iCurCombo >
					 (unsigned int)BRIGHT_GHOST_COMBO_THRESHOLD);
				if (m_pNoteField != nullptr)
					m_pNoteField->DidTapNote(
					  col, bBlind ? TNS_W1 : score, bBright);
				if (score >= m_pPlayerState->m_PlayerOptions.GetCurrent()
							   .m_MinTNSToHideNotes)
					HideNote(col, iRowOfOverlappingNoteOrRow);

				if (pTN->result.tns != TNS_None) {
					if (pTN->type == TapNoteType_HoldHead && bHeld) {
						// odd hack to make roll taps (Step() with bHeld true)
						// not count as marvs
					} else {
						SetJudgment(iRowOfOverlappingNoteOrRow, col, *pTN);
						HandleTapRowScore(iRowOfOverlappingNoteOrRow);
					}
				}
			}
		} else if (NoteDataWithScoring::IsRowCompletelyJudged(
					 m_NoteData, iRowOfOverlappingNoteOrRow)) {
			FlashGhostRow(iRowOfOverlappingNoteOrRow);
		}
	}

	if (score == TNS_None)
		DoTapScoreNone();

	if (!bRelease && col != -1) {
		/* Search for keyed sounds separately.  Play the nearest note. */
		/* XXX: This isn't quite right. As per the above XXX for
		 * iRowOfOverlappingNote, if iRowOfOverlappingNote is set to a previous
		 * note, the keysound could have changed and this would cause the wrong
		 * one to play, in essence playing two sounds in the opposite order.
		 * Maybe this should always perform the search. Still, even that doesn't
		 * seem quite right since it would then play the same (new) keysound
		 * twice which would sound wrong even though the notes were judged as
		 * being correct, above. Fixing the above problem would fix this one as
		 * well. */
		int iHeadRow;
		if (iRowOfOverlappingNoteOrRow != -1 && score != TNS_None) {
			// just pressing a note, use that row.
			// in other words, iRowOfOverlappingNoteOrRow =
			// iRowOfOverlappingNoteOrRow
		} else if (m_NoteData.IsHoldNoteAtRow(col, iSongRow, &iHeadRow)) {
			// stepping on a hold, use it!
			iRowOfOverlappingNoteOrRow = iHeadRow;
		} else {
			// or else find the closest note.
			iRowOfOverlappingNoteOrRow =
			  GetClosestNote(col, iSongRow, MAX_NOTE_ROW, MAX_NOTE_ROW, true);
		}
		if (iRowOfOverlappingNoteOrRow != -1) {
			const TapNote& tn =
			  m_NoteData.GetTapNote(col, iRowOfOverlappingNoteOrRow);
			PlayKeysound(tn, score);
		}
	}

	if (!bRelease) {
		if (m_pNoteField != nullptr &&
			col != -1) { // skip misses to emulate missing.
			if (score != TNS_Miss) {
				m_pNoteField->Step(col, score);
			}
		}
		Message msg("Step");
		msg.SetParam("PlayerNumber", m_pPlayerState->m_PlayerNumber);
		msg.SetParam("MultiPlayer", m_pPlayerState->m_mp);
		msg.SetParam("Column", col);
		MESSAGEMAN->Broadcast(msg);
		// Backwards compatibility
		Message msg2(ssprintf("StepP%d", m_pPlayerState->m_PlayerNumber + 1));
		MESSAGEMAN->Broadcast(msg2);
	}
}
