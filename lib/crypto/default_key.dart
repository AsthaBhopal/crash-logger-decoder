/// Default crash-log decryption private key, pulled from Firebase Remote
/// Config (`crash_logs_private_key`) and baked in here for convenience.
///
/// NOTE: baking the key into the app bundle means anyone with a copy of the
/// build (or this source) can read it — there is no access control on top
/// of it. That's an accepted tradeoff here (crash logs are diagnostic data,
/// not secrets — see the decoder spec §2/§6), chosen over pasting it each
/// session. If `crash_logs_public_key` is ever rotated in Remote Config,
/// update this constant to the matching new private key, and use "Change
/// key" in the app to paste the old one temporarily for logs exported
/// before the rotation.
const String kDefaultPrivateKeyBase64 = 'KCwIsiOsGsKP3qK+fGkY2GKDSWWRZVvxhFJZOm19K38=';
