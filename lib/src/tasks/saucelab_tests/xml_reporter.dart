/// A method to convert Sauce Labs JS unit test results into an xUnit XML report.
library dart_dev.src.tasks.saucelab_tests.xml_reporter;

import 'package:xml/xml.dart';

/// Converts the [results] returned by the [`js-tests/status` endpoint][status-endpoint] into a
/// xUnit test report.
///
/// Sauce Labs runs that didn't complete successfully will be reported as failures.
///
/// [status-endpoint]: https://wiki.saucelabs.com/display/DOCS/JavaScript+Unit+Testing+Methods#JavaScriptUnitTestingMethods-GetJSUnitTestStatus
String sauceResultsToXunitXml(Map results, {bool prettyXml: true}) {
  var builder = new XmlBuilder();
  builder.processing('xml', 'version="1.0" encoding="UTF-8"');

  builder.element('testsuites', nest: () {
    (results['js tests'] as List<Map>).forEach((suite) {
      var suiteResults = suite['result'];

      if (suiteResults is! Map) {
        // Something went wrong with reporting test results; write this suite as failing.
        builder.element('testsuite', attributes: {
          'name': suite['name'],
          'id': suite['url'],
          'failures': 1,
          'skipped': 0,
          'tests': 1,
          'time': 0,
        }, nest: () {
          builder.element('testcase', attributes: {'name': '', 'time': 0,},
              nest: () {
            builder.element('failure', nest: () {
              builder.cdata('An error occurred while running this suite.\n\n'
                  'Result: $suiteResults.\n\n'
                  'Sauce Labs run URL: ${suite['url']}');
            });
          });
        });

        return;
      }

      builder.element('testsuite', attributes: {
        'name': suite['name'],
        'id': suite['url'],
        'failures': suiteResults['failed'],
        // TODO can we even get a skipped count?
        'skipped': 0,
        'tests': suiteResults['total'],
        'time': suiteResults['duration'],
      }, nest: () {
        List<Map> tests = suiteResults['tests'];

        bool reportedAtLeastOneTestCase = false;
        tests.forEach((test) {
          if (!test['result']) {
            reportedAtLeastOneTestCase = true;

            builder.element('testcase', attributes: {
              'name': test['name'],
              'time': test['duration'] ?? 0,
            }, nest: () {
              void addMessage() {
                var message = test['message'];
                if (message != null) {
                  builder.cdata(message);
                }
              }

              builder.element('failure', nest: addMessage);
            });
          }
        });

        if (!reportedAtLeastOneTestCase) {
          builder.element('testcase',
              attributes: {'name': '(all tests in this suite)', 'time': 0,});
        }
      });
    });
  });

  var xml = builder.build();
  return xml.toXmlString(pretty: prettyXml);
}