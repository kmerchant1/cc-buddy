# Boost - Credit Card Rewards Optimizer

A SwiftUI iOS application that helps users optimize their credit card rewards by suggesting the best card to use based on location and purchase category.

## Features

### 🎯 Smart Card Recommendations
- **Location-Based Suggestions**: Uses GPS and Google Places API to identify businesses and recommend the optimal credit card
- **Category-Specific Optimization**: Automatically categorizes purchases (dining, gas, groceries, etc.) and suggests the card with highest rewards
- **Business Type Recognition**: Intelligently maps business types to reward categories for accurate recommendations

### 💳 Virtual Card Interface
- **Apple Wallet Integration**: Seamless integration with Apple Wallet for quick access to physical cards
- **Visual Card Management**: Modern card stack interface with support for custom card images
- **Real-time Reward Calculation**: Shows expected reward multipliers for each card and category

### 📍 Location Services
- **GPS Location Detection**: Automatic location detection for nearby business discovery
- **Manual Coordinate Input**: Option to manually enter coordinates for specific locations
- **Google Places Integration**: Comprehensive business database for accurate categorization

### 📊 Analytics & Tracking
- **Usage Analytics**: Track payment patterns and card usage statistics
- **Firebase Integration**: Cloud-based analytics and user data management
- **Reward Optimization Insights**: Historical data to improve future recommendations

### 🏪 Supported Business Categories
- **Dining**: Restaurants, cafes, bars, fast food, delivery services
- **Gas Stations**: All major gas station chains and independent stations
- **Groceries**: Supermarkets, grocery stores, convenience stores
- **Travel**: Hotels, car rentals, airlines, transit
- **Entertainment**: Movie theaters, streaming services, concerts
- **Drugstores**: Pharmacies and health-related purchases
- **And many more**: Comprehensive category mapping for maximum coverage

## Technical Implementation

### Architecture
- **SwiftUI**: Modern declarative UI framework for iOS
- **MVVM Pattern**: Clean separation of concerns with observable objects
- **Combine Framework**: Reactive programming for data flow management

### Key Components
- `WalletView`: Main interface for card management and selection
- `VirtualCardView`: Smart card recommendation engine
- `WalletManager`: Core business logic for card optimization
- `BusinessSearchController`: Location-based business discovery
- `UserAnalytics`: Usage tracking and insights

### External Integrations
- **Google Places API**: Business identification and categorization
- **Firebase**: Analytics, user management, and cloud storage
- **Core Location**: GPS and location services
- **Apple Wallet**: Native wallet integration

### Supported Card Types
- Major credit card issuers (Amex, Visa, Mastercard, Discover)
- Store-branded cards with specific category bonuses
- Business credit cards with enhanced rewards
- Debit cards with cashback programs

## Setup Instructions

### Prerequisites
- iOS 15.0+
- Xcode 14.0+
- Swift 5.5+
- Valid Apple Developer Account
- Google Places API key
- Firebase project configuration

### Installation
1. Clone the repository
```bash
git clone https://github.com/yourusername/boost-credit-card-app.git
```

2. Install dependencies via Swift Package Manager
```bash
cd boost-credit-card-app
xcodebuild -resolvePackageDependencies
```

3. Configure Firebase
   - Add your `GoogleService-Info.plist` to the project
   - Follow the Firebase setup guide in `Boost/README_FIREBASE.md`

4. Add Google Places API key
   - Create a Google Cloud Platform project
   - Enable Google Places API
   - Add your API key to the project configuration

5. Build and run
```bash
xcodebuild -project Boost.xcodeproj -scheme Boost build
```

## Usage

### Adding Credit Cards
1. Tap the '+' button in the wallet view
2. Enter card details including issuer and card type
3. The app automatically configures reward categories based on known card benefits

### Getting Recommendations
1. Allow location access when prompted
2. Search for businesses or let the app detect your location
3. Select a business to see the optimal card recommendation
4. Tap the wallet button to switch to Apple Wallet

### Managing Cards
1. Use the card selection sheet to switch between cards
2. Access the management menu to delete unused cards
3. View reward multipliers for different categories

## Configuration

### Custom Card Images
Place card images in the `CC_images/` directory following the naming convention:
- `issuer_cardtype.png` (e.g., `amex_platinum.png`)
- Images should be high resolution for best display quality

### Reward Categories
Modify the reward category mappings in `WalletCard+RewardRate.swift` to add support for new card types or update existing reward structures.

## Privacy & Security

- Location data is only used for business identification and is not stored permanently
- Credit card information is stored locally on device only
- Firebase analytics are anonymized and comply with privacy regulations
- No sensitive financial data is transmitted to external servers

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines
- Follow Swift API Design Guidelines
- Maintain comprehensive test coverage
- Update documentation for new features
- Ensure accessibility compliance

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Google Places API for business identification
- Firebase for analytics infrastructure
- Apple for SwiftUI and Wallet integration
- Credit card issuers for reward program information

## Support

For support, please open an issue on GitHub or contact the development team.

---

**Disclaimer**: This app provides suggestions based on publicly available reward program information. Always verify current terms and conditions with your credit card issuer. Reward rates and categories may change without notice. 