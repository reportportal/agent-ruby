# Changelog

## In Git (not released)

* reportportal/reportportal#293 - Re-licence client side to Apache 2.0
* Remove multipart monkeypatch of RestClient. Replace RestClient with HTTP gem as it supports multipart fine
* Make `/api/v1` not required as part of endpoint in report_portal.yml
* Add a mode to use persistent HTTP connection
* Remove JSON slurper
* Support environment variable names prefixed with `rp_` in `reportportal:start_launch` and `reportportal:finish_launch` for consistency with formatters
* Support providing configuration values via upcased environment variables (e.g. `RP_UUID`)
* Report real, not mocked time when Timecop is used
* Add commands to modify/search/delete test items
