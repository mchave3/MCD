# Decisions

## [2026-01-28T15:47:33Z] Technical Decisions
- Storage: `C:\Windows\Temp\MCD\` for post-WinPE state (not ProgramData)
- Context management: Global variables pattern (OSDCloud style)
- Retry: Per-step configuration (maxAttempts, retryDelay)
- Fail-fast: Stop immediately on failure
- Logging: Master log + per-step transcripts
