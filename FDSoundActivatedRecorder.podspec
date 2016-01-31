Pod::Spec.new do |spec|
  s.name         = "FDSoundActivatedRecorder"
  s.version      = "1.0.0"
  s.summary      = "Start recording when the user speaks."
  s.homepage     = "https://github.com/fulldecent/FDTSoundActivatedRecorder"
  s.license      = 'MIT'
  s.author       = { "William Entriken" => "github.com@phor.net" }
  s.source       = { :git => "https://github.com/fulldecent/FDSoundActivatedRecorder.git", :tag => "v1.0.0" }
  s.platform     = :ios, '8.0'
  s.source_files = 'FDSoundActivatedRecorder.swift'
  s.frameworks = 'AVFoundation'
  s.requires_arc = true
end
