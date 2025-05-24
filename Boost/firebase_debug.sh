#!/bin/bash

# Firebase Debug Script for Boost Credit Card App
# This script helps diagnose common Firebase installation issues
# Run with: chmod +x firebase_debug.sh && ./firebase_debug.sh

# ANSI color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Firebase Debug Script for Boost Credit Card App ===${NC}"
echo

# Check for GoogleService-Info.plist
echo -e "${BLUE}Checking for GoogleService-Info.plist...${NC}"
if [ -f "GoogleService-Info.plist" ]; then
    echo -e "${GREEN}✓ GoogleService-Info.plist found in current directory${NC}"
else
    echo -e "${RED}✗ GoogleService-Info.plist not found in current directory${NC}"
    echo -e "${YELLOW}Please make sure GoogleService-Info.plist is added to your project${NC}"
fi
echo

# Check for Package.swift (SPM)
echo -e "${BLUE}Checking for Swift Package Manager integration...${NC}"
PACKAGE_FILE="../Boost.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
if [ -f "$PACKAGE_FILE" ]; then
    echo -e "${GREEN}✓ Swift Package Manager dependencies found${NC}"
    echo -e "${BLUE}Checking for Firebase packages...${NC}"
    if grep -q "firebase-ios-sdk" "$PACKAGE_FILE"; then
        echo -e "${GREEN}✓ Firebase SDK found in Swift Package Manager dependencies${NC}"
    else
        echo -e "${RED}✗ Firebase SDK not found in Swift Package Manager dependencies${NC}"
        echo -e "${YELLOW}Please add the Firebase SDK via File > Add Packages in Xcode${NC}"
    fi
else
    echo -e "${YELLOW}! No Swift Package Manager configuration found${NC}"
fi
echo

# Check for Podfile (CocoaPods)
echo -e "${BLUE}Checking for CocoaPods integration...${NC}"
if [ -f "../Podfile" ]; then
    echo -e "${GREEN}✓ Podfile found${NC}"
    echo -e "${BLUE}Checking for Firebase pods...${NC}"
    if grep -q "Firebase" "../Podfile"; then
        echo -e "${GREEN}✓ Firebase pods found in Podfile${NC}"
        
        # Check for FirebaseFirestoreSwift specifically
        if grep -q "FirebaseFirestoreSwift" "../Podfile"; then
            echo -e "${GREEN}✓ FirebaseFirestoreSwift pod found in Podfile${NC}"
        else
            echo -e "${RED}✗ FirebaseFirestoreSwift pod not found in Podfile${NC}"
            echo -e "${YELLOW}Please add pod 'FirebaseFirestoreSwift' to your Podfile${NC}"
        fi
    else
        echo -e "${RED}✗ Firebase pods not found in Podfile${NC}"
        echo -e "${YELLOW}Please add Firebase pods to your Podfile${NC}"
    fi
else
    echo -e "${YELLOW}! No Podfile found${NC}"
fi
echo

# Check for import statements in code
echo -e "${BLUE}Checking for Firebase import statements in code...${NC}"
FIRESTORE_SWIFT_IMPORTS=$(grep -r "import FirebaseFirestoreSwift" --include="*.swift" . | wc -l | tr -d ' ')
FIRESTORE_IMPORTS=$(grep -r "import FirebaseFirestore" --include="*.swift" . | wc -l | tr -d ' ')
FIREBASE_CORE_IMPORTS=$(grep -r "import FirebaseCore" --include="*.swift" . | wc -l | tr -d ' ')

echo -e "Found ${GREEN}$FIREBASE_CORE_IMPORTS${NC} imports of FirebaseCore"
echo -e "Found ${GREEN}$FIRESTORE_IMPORTS${NC} imports of FirebaseFirestore"
echo -e "Found ${GREEN}$FIRESTORE_SWIFT_IMPORTS${NC} imports of FirebaseFirestoreSwift"

if [ "$FIRESTORE_SWIFT_IMPORTS" -gt 0 ]; then
    echo -e "${YELLOW}! FirebaseFirestoreSwift imports found but module may be missing${NC}"
    echo -e "${YELLOW}  Consider updating code to use standard Firestore API without FirestoreSwift${NC}"
fi
echo

# Recommendation
echo -e "${BLUE}Recommendations:${NC}"
echo -e "1. ${YELLOW}Make sure FirebaseFirestoreSwift is properly included in your dependencies${NC}"
echo -e "2. ${YELLOW}Try cleaning and rebuilding your project (Product > Clean Build Folder)${NC}"
echo -e "3. ${YELLOW}If using SPM, try removing and re-adding the Firebase package${NC}"
echo -e "4. ${YELLOW}Check the 'Other Linker Flags' in Build Settings and add -ObjC if missing${NC}"
echo -e "5. ${YELLOW}If all else fails, try manually implementing Firestore document conversion${NC}"
echo

echo -e "${BLUE}=== Debug Complete ===${NC}" 