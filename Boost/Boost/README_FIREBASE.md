# Firebase Integration Setup

To complete the Firebase setup in this project, follow these steps:

## 1. Add Firebase dependencies using Swift Package Manager

1. In Xcode, go to **File > Add Packages...**
2. In the search field, paste the Firebase iOS SDK repository URL: `https://github.com/firebase/firebase-ios-sdk.git`
3. Select the Firebase iOS SDK package
4. Choose the following Firebase products:
   - FirebaseCore
   - FirebaseFirestore
5. Click "Add Package"

## 2. Ensure GoogleService-Info.plist is properly added

1. Make sure the GoogleService-Info.plist file is included in the app target
2. To check this:
   - Select the GoogleService-Info.plist file in the Project Navigator
   - In the File Inspector (right panel), ensure the target membership checkbox for your app is checked

## 3. Test the integration

1. The app is already set up to initialize Firebase in the BoostApp.swift file
2. The Firebase Firestore integration can be tested by:
   - Viewing a non-Virtual card in the Wallet tab
   - Tapping the info icon (circle with "i") in the bottom right of the card
   - This will attempt to fetch the card's rewards data from Firestore

## 4. Firestore Database Structure

For the Firebase integration to work, your Firestore database should have a "cards" collection with documents that follow this structure:

```json
{
  "issuer": "Amex",
  "name": "Gold",
  "rewards": {
    "dining": 4,
    "groceries": 4, 
    "airlines": 3,
    "other": 1
  }
}
```

The app will query the database using both the "issuer" and "name" fields to find the specific card.

## Troubleshooting

- If you encounter build errors related to Firebase, ensure all dependencies are properly added
- If the app crashes on launch, check that the GoogleService-Info.plist file is correctly configured
- If card rewards data isn't loading, verify your Firestore database structure and rules 