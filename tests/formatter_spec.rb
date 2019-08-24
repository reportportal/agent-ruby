require 'rspec'
require_relative '../lib/formatter/report_portal'

def name
  "Name #{Time.now}"
end

describe ReportPortal do
  require_relative '../lib/settings'

  let(:report_portal) { ReportPortal.new(nil, IO, file: File.join('..', 'config', 'report_portal.yaml')) }

  it 'should create launch' do
    id = report_portal.before_features(nil)
    expect(id).to_not be_nil
    report_portal.after_features(nil)
  end

  context 'launch created' do
    require_relative '../lib/models/test_item'

    before(:each) do
      report_portal.before_features(nil)
    end

    after(:each) do
      report_portal.after_features(nil)
    end

    context 'feature created' do
      before(:each) do
        report_portal.feature_name('Feature', name)
      end

      after(:each) do
        report_portal.after_feature(nil)
      end

      context 'scenario created' do
        before(:each) { report_portal.scenario_name('Scenario', name, "#{__FILE__} #{__LINE__}", nil) }

        it 'should be allow to close as skipped' do
          step_match = double('StepMatch')
          allow(step_match).to receive(:format_args).and_return(name)
          report_portal.step_name('Step', step_match, nil, nil, nil, "#{__FILE__} #{__LINE__}")
          sleep 3
          report_portal.after_step_result('Step', step_match, nil, :skipped, nil, nil, nil, nil)
        end
      end
    end
  end
end
