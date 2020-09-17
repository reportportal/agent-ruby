module ReportPortal
module Cucumber

    class ExtractorCucumber4
        def initialize(config)
          require 'cucumber/formatter/ast_lookup'
          @ast_lookup=::Cucumber::Formatter::AstLookup.new(config)
        end

        # For Cucumber4 we actually return a representation of the gherkin
        # document. So when querying tags, keywords etc, these need to come
        # from the 'feature' attribute of the gherkin document
        def feature(test_case)
            @ast_lookup.gherkin_document(test_case.location.file)
        end

        def feature_location(gherkin)
            gherkin.uri
        end

        def feature_tags(gherkin)
            gherkin.feature.tags
        end

        def feature_name(gherkin)
            "#{gherkin.feature.keyword}: #{gherkin.feature.name}"
        end

        def same_feature_as_previous_test_case?(previous_name,gherkin)
            previous_name == gherkin.uri.split(File::SEPARATOR).last
        end

        def scenario_keyword(test_case)
            @ast_lookup.scenario_source(test_case).scenario.keyword
        end

        def scenario_name(test_case)
            @ast_lookup.scenario_source(test_case).scenario.name
        end

        def step_source(test_step)
            @ast_lookup.step_source(test_step).step
        end

        def step_multiline_arg(test_step)
            test_step.multiline_arg
        end

        def step_backtrace_line(test_step)
            test_step.backtrace_line
        end

        def step_type(test_step)
            case step?(test_step)
                when true
                    'Step'
                when false
                    "#{test_step.text} at #{test_step.location.to_s}"
            end
        end

        def step?(test_step)
            !test_step.hook?
        end
    end

    class ExtractorCucumber3
        def initialize(config)
            require 'cucumber/formatter/hook_query_visitor'
        end

        def feature(test_case)
            test_case.feature
        end

        def feature_location(feature)
            feature.location.file
        end

        def feature_tags(feature)
            feature.tags
        end

        def feature_name(feature)
            "#{feature.keyword}: #{feature.name}"
        end

        def same_feature_as_previous_test_case?(previous_name,feature)
            previous_name == feature.location.file.split(File::SEPARATOR).last
        end

        def scenario_keyword(test_case)
            test_case.keyword
        end

        def scenario_name(test_case)
            test_case.name
        end

        def step_source(test_step)
            test_step.source.last
        end

        def step_multiline_arg(test_step)
            step_source(test_step).multiline_arg
        end

        def step_backtrace_line(test_step)
            test_step.source.last.backtrace_line
        end

        def step_type(test_step)
            case step?(test_step)
                when true
                    'Step'
                when false
                    hook_class_name = test_step.source.last.class.name.split('::').last
                    "#{hook_class_name} at #{test_step.location}"
            end
        end

        def step?(test_step)
            !::Cucumber::Formatter::HookQueryVisitor.new(test_step).hook?
        end
    end

    class Extractor
        def self.create(config)
            if(::Cucumber::VERSION.split('.').map(&:to_i) <=> [4,0,0]) > 0
                ExtractorCucumber4.new(config)
            else
                ExtractorCucumber3.new(config)
            end
        end
    end

end
end
