# SKATEPAY

A [nostr][nostr] chat + crypto wallet client for iPhone.

## Download from App Store

- [SkateConnect](https://apps.apple.com/us/app/skateconnect/id6677058833)

## Overview

- [Gitbook](https://support.skatepark.chat)

## Debug Deeplinking

```
log stream --predicate 'subsystem == "SkateConnect"' --info --style compact
xcrun simctl terminate booted ninja.skate.SkateConnect
xcrun simctl openurl booted "https://skatepark.chat/channel/92ef3ac79a8772ddf16a2e74e239a67bc95caebdb5bd59191c95cf91685dfc8e"
xcrun simctl openurl booted "https://skatepark.chat/user/npub14rzvh48d68f3467faxpz6vm2k3af0c6fpg7y6gmh7hfgpjvj9hgqmwr22g"
xcrun simctl openurl booted "https://skatepark.chat/user/npub1qmmfms6ksy9nsvfv9qam08jkgtwq6fa5qmmgyk34q5p302uewlgsqxv7kg"
```

[nostr]: https://github.com/fiatjaf/nostr

## Nostr Spec Compliance

The following [NIPs](https://github.com/nostr-protocol/nips) are implemented:

- [x] [NIP-01: Basic protocol flow description](https://github.com/nostr-protocol/nips/blob/master/01.md)
- [x] [NIP-04: Encrypted Direct Message](https://github.com/nostr-protocol/nips/blob/master/04.md)
- [x] [NIP-28: Public Chat](https://github.com/nostr-protocol/nips/blob/master/28.md)

## Acknowledgements

- [nostr-sdk-ios](https://github.com/nostr-sdk/nostr-sdk-ios) - [MIT License, Copyright (c) 2023 Nostr SDK](https://github.com/nostr-sdk/nostr-sdk-ios/blob/main/LICENSE)
- [solana-swift](https://github.com/p2p-org/solana-swift) - [MIT License, Copyright (c) 2020 P2P Economy Limited](https://github.com/p2p-org/solana-swift/blob/main/LICENSE)
- [MessageKit](https://github.com/MessageKit/MessageKit) - [MIT License, Copyright (c) 2017-2022 MessageKit](https://github.com/MessageKit/MessageKit/blob/main/LICENSE.md)
- [keychain-swift](https://github.com/evgenyneu/keychain-swift.git) - [MIT License, Copyright (c) 2015 - 2024 Evgenii Neumerzhitckii](https://github.com/evgenyneu/keychain-swift/blob/master/LICENSE)
