#ifndef THEMEMANAGER_H
#define THEMEMANAGER_H

#include "Etterna/Models/Lua/LuaReference.h"
#include "RageUtil/Misc/RageTypes.h"
#include <set>

class IThemeMetric;
class IniFile;
struct lua_State;

enum ElementCategory
{
	EC_BGANIMATIONS,
	EC_FONTS,
	EC_GRAPHICS,
	EC_SOUNDS,
	EC_OTHER,
	NUM_ElementCategory,
	ElementCategory_Invalid
};
/** @brief A special foreach loop going through each ElementCategory. */
#define FOREACH_ElementCategory(ec) FOREACH_ENUM(ElementCategory, ec)
const RString&
ElementCategoryToString(ElementCategory ec);
ElementCategory
StringToElementCategory(const RString& s);

struct Theme;
/** @brief Manages theme paths and metrics. */
class ThemeManager
{
  public:
	ThemeManager();
	~ThemeManager();

	void GetThemeNames(vector<RString>& AddTo);
	void GetSelectableThemeNames(vector<RString>& AddTo);
	int GetNumSelectableThemes();
	bool DoesThemeExist(const RString& sThemeName);
	bool IsThemeSelectable(RString const& name);
	bool IsThemeNameValid(RString const& name);
	RString GetThemeDisplayName(const RString& sThemeName);
	RString GetThemeAuthor(const RString& sThemeName);
	void GetLanguages(vector<RString>& AddTo);
	bool DoesLanguageExist(const RString& sLanguage);
	void SwitchThemeAndLanguage(const RString& sThemeName,
								const RString& sLanguage,
								bool bPseudoLocalize,
								bool bForceThemeReload = false);
	void UpdateLuaGlobals();
	RString GetCurThemeName() const { return m_sCurThemeName; };
	RString GetRealCurThemeName() const { return m_sRealCurThemeName; };
	bool IsThemeLoaded() const { return !m_sCurThemeName.empty(); };
	RString GetCurLanguage() const { return m_sCurLanguage; };
	RString GetCurThemeDir() const
	{
		return GetThemeDirFromName(m_sCurThemeName);
	};
	RString GetNextTheme();
	RString GetNextSelectableTheme();
	void ReloadMetrics();
	void ReloadSubscribers();
	void ClearSubscribers();
	void GetOptionNames(vector<RString>& AddTo);

	static void EvaluateString(RString& sText);

	struct PathInfo
	{
		RString sResolvedPath;
		RString sMatchingMetricsGroup;
		RString sMatchingElement;
	};

	bool GetPathInfo(PathInfo& out,
					 ElementCategory category,
					 const RString& sMetricsGroup,
					 const RString& sElement,
					 bool bOptional = false);
	RString GetPath(ElementCategory category,
					const RString& sMetricsGroup,
					const RString& sElement,
					bool bOptional = false);
	RString GetPathB(const RString& sMetricsGroup,
					 const RString& sElement,
					 bool bOptional = false)
	{
		return GetPath(EC_BGANIMATIONS, sMetricsGroup, sElement, bOptional);
	};
	RString GetPathF(const RString& sMetricsGroup,
					 const RString& sElement,
					 bool bOptional = false)
	{
		return GetPath(EC_FONTS, sMetricsGroup, sElement, bOptional);
	};
	RString GetPathG(const RString& sMetricsGroup,
					 const RString& sElement,
					 bool bOptional = false)
	{
		return GetPath(EC_GRAPHICS, sMetricsGroup, sElement, bOptional);
	};
	RString GetPathS(const RString& sMetricsGroup,
					 const RString& sElement,
					 bool bOptional = false)
	{
		return GetPath(EC_SOUNDS, sMetricsGroup, sElement, bOptional);
	};
	RString GetPathO(const RString& sMetricsGroup,
					 const RString& sElement,
					 bool bOptional = false)
	{
		return GetPath(EC_OTHER, sMetricsGroup, sElement, bOptional);
	};
	void ClearThemePathCache();

	bool HasMetric(const RString& sMetricsGroup, const RString& sValueName);
	void PushMetric(Lua* L,
					const RString& sMetricsGroup,
					const RString& sValueName);
	RString GetMetric(const RString& sMetricsGroup, const RString& sValueName);
	int GetMetricI(const RString& sMetricsGroup, const RString& sValueName);
	float GetMetricF(const RString& sMetricsGroup, const RString& sValueName);
	bool GetMetricB(const RString& sMetricsGroup, const RString& sValueName);
	RageColor GetMetricC(const RString& sMetricsGroup,
						 const RString& sValueName);
	LuaReference GetMetricR(const RString& sMetricsGroup,
							const RString& sValueName);
#if !defined(SMPACKAGE)
	apActorCommands GetMetricA(const RString& sMetricsGroup,
							   const RString& sValueName);
#endif

	void GetMetric(const RString& sMetricsGroup,
				   const RString& sValueName,
				   LuaReference& valueOut);

	// Languages
	bool HasString(const RString& sMetricsGroup, const RString& sValueName);
	RString GetString(const RString& sMetricsGroup, const RString& sValueName);
	void GetString(const RString& sMetricsGroup,
				   const RString& sValueName,
				   RString& valueOut)
	{
		valueOut = GetString(sMetricsGroup, sValueName);
	}
	void FilterFileLanguages(vector<RString>& asElementPaths);

	void GetMetricsThatBeginWith(const RString& sMetricsGroup,
								 const RString& sValueName,
								 set<RString>& vsValueNamesOut);

	RString GetMetricsGroupFallback(const RString& sMetricsGroup);

	static RString GetBlankGraphicPath();

	// needs to be public for its binding to work
	void RunLuaScripts(const RString& sMask, bool bUseThemeDir = false);

	// For self-registering metrics
	static void Subscribe(IThemeMetric* p);
	static void Unsubscribe(IThemeMetric* p);

	// Lua
	void PushSelf(lua_State* L);

  protected:
	void LoadThemeMetrics(const RString& sThemeName, const RString& sLanguage_);
	RString GetMetricRaw(const IniFile& ini,
						 const RString& sMetricsGroup,
						 const RString& sValueName);
	bool GetMetricRawRecursive(const IniFile& ini,
							   const RString& sMetricsGroup,
							   const RString& sValueName,
							   RString& sRet);

	bool GetPathInfoToAndFallback(PathInfo& out,
								  ElementCategory category,
								  const RString& sMetricsGroup,
								  const RString& sFile);
	bool GetPathInfoToRaw(PathInfo& out,
						  const RString& sThemeName,
						  ElementCategory category,
						  const RString& sMetricsGroup,
						  const RString& sFile);
	static RString GetThemeDirFromName(const RString& sThemeName);
	RString GetElementDir(const RString& sThemeName);
	static RString GetMetricsIniPath(const RString& sThemeName);
	static void GetLanguagesForTheme(const RString& sThemeName,
									 vector<RString>& asLanguagesOut);
	static RString GetLanguageIniPath(const RString& sThemeName,
									  const RString& sLanguage);
	void GetOptionalLanguageIniPaths(vector<RString>& vsPathsOut,
									 const RString& sThemeName,
									 const RString& sLanguage);
	RString GetDefaultLanguage();

	RString m_sCurThemeName;
	RString m_sRealCurThemeName = "";
	RString m_sCurLanguage;
	bool m_bPseudoLocalize;
};

extern ThemeManager*
  THEME; // global and accessible from anywhere in our program

#endif
