# Step 13: Social & Web3 Auth (Google/Apple Sign-In & DePIN Web3 Wallet Connect)

## Overview
This milestone integrates **Social & Web3 Authentication** into the GroupNav mobile ecosystem. It addresses two critical rider personas:
1. **One-Tap Consumer Pilots**: Riders wanting instantaneous onboarding via federated identity providers (Google Sign-In and Apple Sign-In).
2. **DePIN Telemetry Pilots**: Web3 riders connecting self-custody crypto wallets (MetaMask, Phantom, and WalletConnect across Polygon, Ethereum, and Solana) to verify decentralized physical infrastructure ride telemetry and accrue on-chain `$NAV` token rewards (`+4.2 NAV/hr`).

---

## 1. How It Was Done

### Technical Breakdown & Mechanics

1. **Decoupled Social Authentication Architecture (`ISocialAuthService`)**:
   - Defined `SocialAuthProvider` (`google`, `apple`) and `SocialAuthResult` encapsulates `email`, `displayName`, `providerId`, `idToken`, and `avatarUrl`.
   - Created `ISocialAuthService` contract with `signInWithGoogle()`, `signInWithApple()`, and `signOut()`.
   - Built `LocalSocialAuthService` for production OAuth/federated exchange with AWS Cognito Identity Pool.
   - Built `MockSocialAuthService` to enable 100% deterministic test execution in headless environments without external network or OAuth pop-up requirements.

2. **Decoupled Web3 Wallet Service (`IWeb3WalletService`)**:
   - Defined `Web3WalletType` (`metamask`, `phantom`, `walletConnect`) and `Web3Chain` (`polygon`, `ethereum`, `solana`).
   - Defined `Web3ConnectionResult` tracking `walletAddress`, `chain`, `signature`, and `balanceNAV`, with formatting helper `truncatedAddress` (e.g. `0x71C2...9B2d`).
   - Created `IWeb3WalletService` contract with `connectWallet()`, `signChallenge()`, `disconnectWallet()`, and `getNavBalance()`.
   - Built `ProductionWeb3WalletService` utilizing deep-linking URI schemes (`metamask://`, `phantom://`, `wc:`) and Sign-In with Ethereum (SIWE) cryptographic nonces.
   - Built `MockWeb3WalletService` for headless testing of wallet connection, user cancellations, and balance synchronizations.

3. **Domain Models & State Management**:
   - Extended `PilotProfile` with Web3 and identity metadata:
     - `walletAddress`: Active public key/address of the linked wallet.
     - `authProviderType`: Provider identifier (`'cognito'`, `'google'`, `'apple'`, `'web3'`, `'guest'`).
     - `navTokenBalance`: Double representing earned DePIN ride tokens.
     - `isWalletConnected` & `truncatedWallet` computed accessors.
   - Extended `AuthState` with:
     - `isSocialAuthLoading`: Boolean tracking pending Google/Apple OAuth requests.
     - `isWeb3Connecting`: Boolean tracking wallet modal connection and challenge signing.
     - `connectedWallet`: Active `Web3ConnectionResult` instance.
     - `clearConnectedWallet()`: Immutable state helper ensuring clean unlinking without Dart null-coalescing retention bugs.
   - Enriched `AuthNotifier`:
     - `signInWithGoogle()` & `signInWithApple()`: Creates authenticated pilot profiles with federated credentials and immediately transitions to the active map shell.
     - `signInWithWeb3(walletType, {chain})`: Connects wallet, verifies cryptographic challenge, provisions a Web3 pilot profile (`0x...` callsign), and grants authenticated access.
     - `linkWeb3Wallet(walletType, {chain})`: Allows riders already authenticated via email/Cognito to link their Web3 wallet in Profile Settings for DePIN telemetry rewards.
     - `disconnectWeb3Wallet()`: Unlinks wallet and resets reward balance.

4. **Tactical UI Components & Integration**:
   - Created `SocialAuthButtons`: High-contrast Google and Apple one-tap buttons adhering to platform design guidelines and Convoy Telemetry dark aesthetics.
   - Created `Web3WalletModal`: Tactical bottom-sheet modal featuring:
     - DePIN telemetry banner highlighting `+4.2 NAV/hr` on-chain verification.
     - Multi-chain selector for Polygon (PoS), Ethereum Mainnet, and Solana.
     - Provider selection tiles for MetaMask, Phantom, and WalletConnect.
     - Dynamic button adapting between standalone sign-in and in-app profile wallet linking.
   - Integrated into `AuthOnboardingScreen`: Positioned below the primary sign-in form with a clear divider, enabling riders to authenticate via Google, Apple, or Web3 directly.
   - Integrated into `ProfileIdentityCard` & `RiderSettingsScreen`: Embedded a "DEPIN TELEMETRY WALLET" row displaying the active wallet address, `$NAV` token rewards badge, and Connect/Disconnect triggers.

---

## 2. Why It Was Done This Way

### Architectural Decisions & Tradeoffs

- **Abstract Service Interfaces (`ISocialAuthService` & `IWeb3WalletService`)**:
   - Native crypto wallet apps (MetaMask, Phantom) and social OAuth SDKs require platform-dependent intent handlers and external browser redirects that cannot run inside automated headless CI test environments. Decoupling the service boundaries through abstract interfaces guarantees that 100% of state transitions, error recovery paths, and UI interactions are verified with zero mock compromises in production code.
- **Support for Both Web3 Direct Sign-In and Wallet Linking**:
   - Web3-native riders can sign in directly using their wallet as their primary identity (SIWE), while riders who registered via standard AWS Cognito email/password can optionally link a wallet later in settings to earn DePIN ride rewards. This prevents forcing Web3 complexity on traditional riders while providing first-class utility to crypto-native pilots.
- **Multi-Chain Adaptability (Polygon, Ethereum, Solana)**:
   - DePIN telemetry networks frequently leverage high-throughput, low-fee chains (such as Polygon PoS or Solana) for frequent proof-of-ride micro-rewards, while pilots may maintain primary identities on Ethereum. The modal explicitly supports chain selection while auto-selecting appropriate wallet providers (e.g. Phantom for Solana).
- **Explicit Immutable `clearConnectedWallet()` Method**:
   - In Dart, using `state.copyWith(connectedWallet: null)` fails to clear nullable fields due to the `connectedWallet ?? this.connectedWallet` null-coalescing pattern. Providing an explicit `clearConnectedWallet()` method cleanly resets the connection state without accidental field retention.

---

## 3. Verification Evidence

### Automated Test Execution
- Executed `flutter test test/auth_test.dart`:
  - **Result**: `All 25 tests passed (100% success rate)`.
  - Verified test groups:
    - `Social Authentication Tests`: Google sign-in success, Google sign-in failure handling, Apple sign-in success.
    - `Web3 Wallet & DePIN Telemetry Tests`: Web3 sign-in with MetaMask on Polygon, Web3 rejection handling, wallet linking and unlinking with `$NAV` balance updates.
    - `Social & Web3 Widget Tests`: `SocialAuthButtons` tap callbacks, `Web3WalletModal` rendering, chain selection, and provider connection dispatch.
- Executed full project test suite via `flutter test`:
  - **Result**: `89 of 89 tests passed (100% success rate)` across all unit, widget, and state management test files.

### Static Code Analysis
- Executed `flutter analyze` across `mobile/`:
  - **Result**: `No issues found! (ran in 3.6s)`.
  - Zero warnings, zero errors, and zero lint hints.
