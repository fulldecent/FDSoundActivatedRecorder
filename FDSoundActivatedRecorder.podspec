Pod::Spec.new do |s|
  s.name         = "FDSoundActivatedRecorder"
  s.version      = "3.1.0"
  s.summary      = "Start recording when the user speaks"
  s.description  = <<-DESC
                   All you have to do is tell us when to start listening. Then we wait for an audible noise and start recording. This is mostly useful for user speech input and the "Start talking now prompt".
                   DESC
  s.homepage     = "https://github.com/fulldecent/FDSoundActivatedRecorder"
  s.screenshots  = "http://i.imgur.com/XD9QBjG.png"
  s.license      = "MIT"
  s.author       = { "William Entriken" => "github.com@phor.net" }
  s.source       = { :git => "https://github.com/fulldecent/FDSoundActivatedRecorder.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/fulldecent'
  s.platform     = :ios, '10.3'
  s.requires_arc = true
  s.swift_version = '5.0'
  s.source_files = 'FDSoundActivatedRecorder/FDSoundActivatedRecorder/FDSoundActivatedRecorder.swift'
end
