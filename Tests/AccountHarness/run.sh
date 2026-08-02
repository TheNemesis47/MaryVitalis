#!/bin/bash
#
# Banco di prova degli account, senza target di test in Xcode.
#
# Compila per macOS il codice di produzione vero — modelli SwiftData,
# CredentialStore, ProfileStore, RoutineFactory — e ci gira sopra le verifiche
# su registrazione, accesso, cambio password, Sign in with Apple e cancellazione
# a cascata del profilo. Il database è in memoria; le credenziali finiscono nel
# Portachiavi della macchina e vengono ripulite alla fine.
#
# I soli tipi sostituiti sono quelli che fuori da iOS non esistono
# (ActivityKit, WidgetKit): stanno in cima a Harness.swift.
#
# Uso:  Tests/AccountHarness/run.sh

set -e
cd "$(dirname "$0")"
ROOT="$(cd ../.. && pwd)"
P="$ROOT/MaryVitalis"
OUT=$(mktemp -d)

swiftc -parse-as-library \
  "$P/Data/Models.swift" \
  "$P/Data/SeedRoutines.swift" \
  "$P/Data/RoutineFactory.swift" "$P/Data/GymFactory.swift" "$P/Data/InviteCode.swift" \
  "$P/Data/GymBirreria.swift" "$P/Data/HistoricRoutines.swift" \
  "$P/Model/GymMachine.swift" \
  "$P/Model/UserRole.swift" \
  "$P/Model/Routine.swift" "$P/Model/GymLocation.swift" "$P/Model/GymMapData.swift" \
  "$P/Store/CredentialStore.swift" \
  "$P/Store/SecureSessionStore.swift" \
  "$P/Store/AppleSignIn.swift" \
  "$P/Store/ProfileStore.swift" "$P/Store/RoutineEditing.swift" "$P/Store/GymSharing.swift" \
  Harness.swift \
  -o "$OUT/harness"

"$OUT/harness"
STATUS=$?
rm -rf "$OUT"
exit $STATUS
