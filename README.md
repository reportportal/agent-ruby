# Ruby Cucumber and RSpec formatters for ReportPortal

 [Download](https://rubygems.org/gems/reportportal)
 
[![Join Slack chat!](https://reportportal-slack-auto.herokuapp.com/badge.svg)](https://reportportal-slack-auto.herokuapp.com)
[![stackoverflow](https://img.shields.io/badge/reportportal-stackoverflow-orange.svg?style=flat)](http://stackoverflow.com/questions/tagged/reportportal)
[![UserVoice](https://img.shields.io/badge/uservoice-vote%20ideas-orange.svg?style=flat)](https://rpp.uservoice.com/forums/247117-report-portal)
[![Build with Love](https://img.shields.io/badge/build%20with-❤%EF%B8%8F%E2%80%8D-lightgrey.svg)](http://reportportal.io?style=flat)


## Installation

Use Ruby 2.2+

**Rubygems**

From https://rubygems.org

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
gem install reportportal
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

or

Add `gem 'reportportal', git: 'https://github.com/reportportal/agent-ruby.git'` to your `Gemfile`. Run `bundle install`.

## Usage (examples)

* With Cucumber:

```cucumber <other options> -f ReportPortal::Cucumber::Formatter```

* With Cucumber and parallel_tests gem:

```parallel_cucumber <some options> -o '<some other options> -f ReportPortal::Cucumber::ParallelFormatter'```

* With RSpec:

```rspec <other options> -f ReportPortal::RSpec::Formatter```

## Configuration
Create report_portal.yml configuration file in one of the following folders of your project: '.', './.config', './config' (see report_portal.yaml.example).
Alternatively specify path to configuration file via rp_config environment variable.

Supported settings:

 - uuid - uuid of the ReportPortal user
 - endpoint - URI of ReportPortal web service where requests should be sent
 - launch - launch name
 - description - custom launch description
 - project - project name
 - tags - array of tags for the launch
 - formatter_modes - array of modes that modify formatter behavior, see [formatter modes](#formatter_modes)
 - launch_id - id of previously created launch (to be used if formatter_modes contains attach_to_launch)
 - file_with_launch_id - path to file with id of launch (to be used if formatter_modes contains attach_to_launch)
 - disable_ssl_verification - set to true to disable SSL verification on connect to ReportPortal (potential security hole!). Set `disable_ssl_verification` to `true` if you see the following error:
```
Request to https://rp.epam.com/reportportal-ws/api/v1/pass-team/launch//finish produced an exception: RestClient::SSLCertificateNotVerified: SSL_connect returned=1 errno=0 state=SSLv3 read server certificate B: certificate verify failed
```
 - is_debug - set to true to mark the launch as 'DEBUG' (it will appear in Debug tab in Report Portal)
 - use_standard_logger - set to true to enable logging via standard Ruby Logger class to ReportPortal. Note that log messages are transformed to strings before sending.

Each of these settings can be overridden by an environment variable with the same name and 'rp_' prefix (e.g. 'rp_uuid' for 'uuid'). Environment variables take precedence over YAML configuration.
Environment variable values are parsed as YAML entities.

## WebMock configuration
If you use WebMock for stubbing and setting expectations on HTTP requests in Ruby,
add this to your configuration file (for RSpec it would be `rails_helper.rb` or `spec_helper.rb`)

```ruby
WebMock.disable_net_connect!(:net_http_connect_on_start => true, :allow_localhost => true, :allow => [/rp\.epam\.com/]) # Don't break Net::HTTP
```

<a name="formatter_modes"></a>
## Formatter modes

The following modes are supported:

| Name | Purpose |
| --- | --- |
| attach_to_launch | Do not create a new launch but add executing features/scenarios to an existing launch. Use launch_id or file_with_launch_id settings to configure that. If they are not present client will check rp_launch_id.tmp in `Dir.tmpdir`)
| use_same_thread_for_reporting | Send reporting commands in the same main thread used for running tests. This mode is useful for debugging this Report Portal client. It changes default behavior to send commands in the separate thread. Default behavior is there not to slow test execution. |

## Logging
Experimental support for three common logging frameworks was added:

- Logger (part of standard Ruby library)
- [Logging](http://rubygems.org/gems/logging)
- [Log4r](https://rubygems.org/gems/log4r)

To use Logger, set use_standard_logger parameter to true (see Configuration chapter). For the other two corresponding appenders/outputters are available under reportportal/logging.

## Parallel formatter

ReportPortal::Cucumber::ParallelFormatter can be used for tests started via parallel_tests gem.

Note: Launch id is shared between independent processes (as is the case with parallel_tests gem) via a file in `Dir.tmpdir`.

## Links

 - [ReportPortal](https://github.com/reportportal/)
