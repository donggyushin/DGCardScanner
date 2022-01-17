Pod::Spec.new do |s|
    s.name             = 'DGCardScanner'
    s.version          = '1.0.1'
    s.summary          = 'A credit card scanner'
    s.homepage         = 'https://github.com/donggyushin/DGCardScanner'
    s.license          = { :type => 'MIT', :file => 'LICENSE.md' }
    s.author           = { 'donggyushin' => 'donggyu9410@gmail.com' }
    s.source           = { :git => 'https://github.com/donggyushin/DGCardScanner.git', :tag => s.version.to_s }
    s.ios.deployment_target = '13.0'
    s.swift_version = '5.5'
    s.source_files = 'Sources/DGCardScanner/**/*'
  end
