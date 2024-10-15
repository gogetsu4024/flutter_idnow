Pod::Spec.new do |s|
  s.name             = 'flutter_idnow'
  s.version          = '0.0.1'
  s.summary          = 'Flutter wrapper for IDNOW'
  s.description      = <<-DESC
Flutter wrapper for IDNOW
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*.{h,m}' # Adjust this if you keep Swift
  s.dependency       'Flutter'
  s.platform         = :ios, '9.0'  # or higher based on your app
  s.static_framework  = true
  s.dependency       'IDnowSDK', '~> 8.4.0'
  s.pod_target_xcconfig = {
    "HEADER_SEARCH_PATHS" => '"${PODS_ROOT}/IDnowSDK/include"'
  }
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'VALID_ARCHS[sdk=iphonesimulator*]' => 'x86_64'
  }
end