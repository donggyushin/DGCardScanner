# DGCardScanner

A credit card scanner
<div>
<img src="https://user-images.githubusercontent.com/34573243/149662861-5a0fa7bc-e7ab-4f67-bd4d-6ca81f9efe28.gif" width=250 />
</div>

## Requirements
- iOS 13.0+
- Swift 5.5+
- Xcode 10.0+

## Installation

### SPM
```
File > Add Packages > https://github.com/donggyushin/DGCardScanner
```

### CocoaPod
```
pod 'DGCardScanner', :git => 'https://github.com/donggyushin/DGCardScanner'
```

## Usage
```
DGCardScanner.appearance.helperText = "Change helper text"
let scannerView = DGCardScanner.getScanner { number, date, name in

}
self.present(scannerView, animated: true)
```

## High hit rate cards 
```Please let me know if there is a card that you want to add by posting at Issues tab```
- NH
- Shinhan
- WOORI
- KB
- KAKAOBANK

