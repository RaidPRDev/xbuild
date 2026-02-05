
Run in WSL or Linux.
```sh
./build.sh
```


Libraries
- Node
- rbenv
- cocoapods
- Xcode/CLI Tools
- xcpretty
- ruby
- git



Test iOS Signing Process
```sh
register_keychain_profile.sh dev TESTER UID_TESTER_20250818-082526 /Users/Rafael/RaidX/Clients/TESTER/UID_TESTER_20250818-082526/certs/iOS_Dist_Key.p12 "#SweetRush@" ELSO_Staging_AppStoreTestFlight /Users/Rafael/RaidX/Clients/TESTER/UID_TESTER_20250818-082526/certs/profiles/ELSO_Staging_AppStoreTestFlight.mobileprovision
```

Read Provisioning Profile
```sh
# You need a default keychain activated in order to read the provisioning
security default-keychain -s "$HOME/Library/Keychains/login.keychain-db"

# Unlock it to access
security unlock-keychain -p "<your-login-password>" "$HOME/Library/Keychains/login.keychain-db"

# Display contents
CLIENT_ID="TESTER"
BUILD_ID="UID_TESTER_20250819-011049"
PROVISION="ELSO_Staging_AppStoreTestFlight.mobileprovision"
security cms -D -i "/Users/Rafael/RaidX/Clients/$CLIENT_ID/$BUILD_ID$/certs/profiles/$PROVISION$" | plutil -p -

# Partial Result: 
  "AppIDName" => "ELSO Bedside App Staging"
  "ApplicationIdentifierPrefix" => [
    0 => "NFUPVTVQP8"
  ]
  ...
```

Parse provisioning to then decode the Base64/DER
```sh
CLIENT_ID="TESTER"
BUILD_ID="UID_TESTER_20250819-011049"
PROVISION="ELSO_Staging_AppStoreTestFlight.mobileprovision"
security cms -D -i "/Users/Rafael/RaidX/Clients/$CLIENT_ID/$BUILD_ID/certs/profiles/$PROVISION" \
  | plutil -extract DeveloperCertificates.0 xml1 -o - - \
  | xmllint --xpath "string(//data)" - \
  | base64 --decode \
  | openssl x509 -inform DER -noout -subject

# Result: subject=UID=NFUPVTVQP8, CN=iPhone Distribution: Mark Mastro (NFUPVTVQP8), OU=NFUPVTVQP8, O=Mark Mastro, C=US
```


## Troubleshooting

Issue: Build Error Message
Pods-App does not support provisioning profiles. Pods-App does not support provisioning profiles, but provisioning profile ent_frontwork has been manually specified. Set the provisioning profile value to "Automatic" in the build settings editor. (in target 'Pods-App' from project 'Pods')

```sh
# Add this code to the Podfile:
# Workaround build fix 08-19-2025 
# The following variables get overriden when
# set programmatically.
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['EXPANDED_CODE_SIGN_IDENTITY'] = ""
      config.build_settings['CODE_SIGNING_REQUIRED'] = "NO"
      config.build_settings['CODE_SIGNING_ALLOWED'] = "NO"
    end
  end
end
```