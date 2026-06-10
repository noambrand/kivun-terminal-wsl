// kivun-launcher.cpp - native no-console-flash launcher for Kivun Terminal.
//
// Continuation of PR #83 (@zuwasi). Architecture per the PR review: this is
// a THIN HIDDEN SHELL over kivun-terminal.bat - every check the launcher
// performs (config parsing, HTA folder picker, WSL health check, Claude
// auto-install, root-user guard, WSLENV passthrough) stays in the .bat.
// This exe only:
//   1. runs the .bat sitting next to it in a console that has NO window
//      (CREATE_NO_WINDOW gives a real console, so `timeout /t` and console
//      semantics inside the .bat keep working - it is just invisible),
//      forwarding our command line verbatim (the Explorer context menu
//      passes a folder path as "%1"/"%V"),
//   2. sets KIVUN_HIDDEN=1 so the .bat suppresses interactive prompts and
//      keeps the WSL bridge out of the taskbar (its start /B branch),
//   3. waits for the .bat and, on a non-zero exit, shows the tail of
//      LAUNCH_LOG.txt in a MessageBox - failures must be VISIBLE
//      (the v1.1.0 lesson; see CLAUDE.md).
//
// Deliberately NOT done here:
//   - no stdin/stdout redirection: the .bat's `timeout /t 3 /nobreak`
//     aborts with "Input redirection is not supported" when stdin is not
//     a console handle,
//   - no DETACHED_PROCESS: the child needs a (windowless) console,
//   - no logic duplicated from the .bat.
//
// KIVUN_SUPPRESS_ERROR_UI=1 suppresses the failure MessageBox (headless CI).

#include <windows.h>
#include <stdio.h>    // swprintf_s
#include <stdlib.h>
#include <string.h>

static const wchar_t kBatName[] = L"kivun-terminal.bat";
static const wchar_t kTitle[]   = L"Kivun Terminal";

static BOOL ErrorUiSuppressed(void)
{
    wchar_t flag[8];
    return GetEnvironmentVariableW(L"KIVUN_SUPPRESS_ERROR_UI", flag, 8)
           && flag[0] == L'1';
}

// Skip argv[0] of a raw command line; return the verbatim tail (quotes intact).
static const wchar_t *CmdLineTail(const wchar_t *c)
{
    if (*c == L'"') { ++c; while (*c && *c != L'"') ++c; if (*c) ++c; }
    else            { while (*c && *c > L' ') ++c; }
    while (*c == L' ' || *c == L'\t') ++c;
    return c;
}

// Best-effort: append the last ~25 lines of LAUNCH_LOG.txt to the dialog
// text. The log is mostly OEM-codepage text from cmd `echo >>`; redirected
// wsl.exe output inside it is UTF-16 and would embed NULs, so blank those.
static void AppendLogTail(wchar_t *dst, size_t dstCount)
{
    wchar_t logPath[MAX_PATH];
    if (!GetEnvironmentVariableW(L"LOCALAPPDATA", logPath, MAX_PATH)) return;
    wcscat_s(logPath, MAX_PATH, L"\\Kivun-WSL\\LAUNCH_LOG.txt");

    HANDLE h = CreateFileW(logPath, GENERIC_READ,
                           FILE_SHARE_READ | FILE_SHARE_WRITE, NULL,
                           OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (h == INVALID_HANDLE_VALUE) return;

    LARGE_INTEGER size = { 0 };
    GetFileSizeEx(h, &size);
    const DWORD kTail = 4096;
    if (size.QuadPart > kTail) {
        LARGE_INTEGER off;
        off.QuadPart = size.QuadPart - kTail;
        SetFilePointerEx(h, off, NULL, FILE_BEGIN);
    }
    char buf[4097];
    DWORD got = 0;
    ReadFile(h, buf, kTail, &got, NULL);
    CloseHandle(h);
    if (!got) return;
    for (DWORD i = 0; i < got; ++i) if (buf[i] == '\0') buf[i] = ' ';

    wchar_t wide[4097];
    int n = MultiByteToWideChar(CP_OEMCP, 0, buf, (int)got, wide, 4096);
    if (n <= 0) return;
    wide[n] = L'\0';

    int lines = 0;
    wchar_t *p = wide + n;
    while (p > wide && lines < 25) { --p; if (*p == L'\n') ++lines; }
    if (lines == 25) ++p;

    wcscat_s(dst, dstCount, L"\n\nRecent launch log:\n");
    wcscat_s(dst, dstCount, p);
    wcscat_s(dst, dstCount, L"\n\nFull log: ");
    wcscat_s(dst, dstCount, logPath);
}

static void ShowFailure(DWORD exitCode)
{
    if (ErrorUiSuppressed()) return;
    static wchar_t msg[8192];
    swprintf_s(msg, 8192,
        L"Kivun Terminal could not start (exit code %lu).", exitCode);
    AppendLogTail(msg, 8192);
    wcscat_s(msg, 8192,
        L"\n\nRun \"Kivun Diagnostics\" from the Start Menu and email the "
        L"report to noambbb@gmail.com for help.");
    MessageBoxW(NULL, msg, kTitle, MB_ICONERROR | MB_OK | MB_SETFOREGROUND);
}

int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int)
{
    // kivun-terminal.bat lives next to this exe ($INSTDIR).
    wchar_t bat[MAX_PATH];
    DWORD n = GetModuleFileNameW(NULL, bat, MAX_PATH);
    if (n == 0 || n >= MAX_PATH) return 1;
    while (n && bat[n - 1] != L'\\') --n;
    bat[n] = L'\0';
    wcscat_s(bat, MAX_PATH, kBatName);

    wchar_t comspec[MAX_PATH];
    if (!GetEnvironmentVariableW(L"COMSPEC", comspec, MAX_PATH)) {
        GetSystemDirectoryW(comspec, MAX_PATH);
        wcscat_s(comspec, MAX_PATH, L"\\cmd.exe");
    }

    const wchar_t *tail = CmdLineTail(GetCommandLineW());

    // cmd /S /C strips exactly the OUTER quote pair, so the quoted bat path
    // and the (possibly quoted) forwarded args coexist:
    //   "cmd.exe" /S /C ""C:\..\kivun-terminal.bat" "C:\My Dir""
    size_t len = wcslen(comspec) + wcslen(bat) + wcslen(tail) + 32;
    wchar_t *cmd = (wchar_t *)malloc(len * sizeof(wchar_t));
    if (!cmd) return 1;
    swprintf_s(cmd, len, L"\"%s\" /S /C \"\"%s\"%s%s\"",
               comspec, bat, *tail ? L" " : L"", tail);

    // Inherited by cmd -> the .bat: suppress prompts, use the /B launch path.
    SetEnvironmentVariableW(L"KIVUN_HIDDEN", L"1");

    STARTUPINFOW si = { sizeof(si) };
    si.dwFlags = STARTF_USESHOWWINDOW;
    si.wShowWindow = SW_HIDE;
    PROCESS_INFORMATION pi = { 0 };

    if (!CreateProcessW(NULL, cmd, NULL, NULL, FALSE, CREATE_NO_WINDOW,
                        NULL, NULL /* inherit cwd (context-menu dir) */,
                        &si, &pi)) {
        DWORD err = GetLastError();
        free(cmd);
        if (!ErrorUiSuppressed()) {
            wchar_t msg[1024];
            swprintf_s(msg, 1024,
                L"Failed to launch kivun-terminal.bat (error %lu).\n\n%s\n\n"
                L"Re-run the Kivun Terminal installer if the file is missing.",
                err, bat);
            MessageBoxW(NULL, msg, kTitle,
                        MB_ICONERROR | MB_OK | MB_SETFOREGROUND);
        }
        return 1;
    }
    free(cmd);

    // The .bat exits seconds after spawning the WSL bridge (start /B), so
    // this wait is short - the exe never lingers for the whole session.
    WaitForSingleObject(pi.hProcess, INFINITE);
    DWORD code = 1;
    GetExitCodeProcess(pi.hProcess, &code);
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);

    if (code != 0) ShowFailure(code);
    return (int)code;   // CI asserts bat -> cmd -> exe exit-code propagation
}
