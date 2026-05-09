// Kivun Terminal — native Windows launcher (no console flash, no VBS)
// Spawns wsl.exe -> bash -> kivun-launch.sh, then exits immediately.
// Build: cl /EHsc /O2 /W3 kivun-launcher.cpp /Fe:KivunTerminal.exe /link /SUBSYSTEM:WINDOWS user32.lib

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int) {
    // Single command string handed to CreateProcessW. wsl.exe inherits no
    // console (CREATE_NO_WINDOW) so nothing flashes on the desktop.
    // Invoke a fixed-path launcher script inside WSL. We deliberately do
    // NOT background with nohup — when wsl.exe exits, any disowned child
    // gets reaped by the WSL session shutdown before WSLg can parent
    // Konsole. Instead, the launcher exec's into konsole, so wsl.exe
    // blocks until the user closes the Konsole window. The launcher exe
    // itself returns immediately because we use DETACHED_PROCESS.
    wchar_t cmd[] =
        L"wsl.exe -d Ubuntu-24.04 /home/danie/.local/bin/kivun-start.sh";

    STARTUPINFOW si = { sizeof(si) };
    PROCESS_INFORMATION pi = {};
    si.dwFlags = STARTF_USESHOWWINDOW;
    si.wShowWindow = SW_HIDE;

    if (!CreateProcessW(NULL, cmd, NULL, NULL, FALSE,
                        CREATE_NO_WINDOW | DETACHED_PROCESS,
                        NULL, NULL, &si, &pi)) {
        MessageBoxW(NULL,
            L"Failed to launch wsl.exe.\n\nIs WSL installed and "
            L"is the Ubuntu-24.04 distro available?",
            L"Kivun Terminal", MB_ICONERROR | MB_OK);
        return 1;
    }
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    return 0;
}
