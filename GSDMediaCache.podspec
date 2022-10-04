Pod::Spec.new do |spec|

  spec.name         = "GSDMediaCache"
  spec.version      = "1.3.0"
  spec.summary      = "边下边播框架for AVPlayer"
  spec.homepage     = "https://github.com/xq-120/GSDMediaCache"
  spec.license      = "MIT"

  spec.author       = { "xq" => "1204556447@qq.com" }

  spec.platform     = :ios, "10.0"

  spec.source       = { :git => "https://github.com/xq-120/GSDMediaCache.git", :tag => "#{spec.version}" }
  spec.source_files = "GSDMediaCache/*.{h,m}"

  spec.frameworks   = "Foundation"

  spec.requires_arc = true

  spec.dependency "YYModel", "~> 1.0.4"

end
