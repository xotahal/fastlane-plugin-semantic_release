describe Fastlane::Actions::SemanticReleaseAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The semantic_release plugin is working!")

      Fastlane::Actions::SemanticReleaseAction.run(nil)
    end
  end
end
