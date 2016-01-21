import 'dart:io';
import 'dart:convert';

class XunitFailure {
  String name;
  String stack;

  XunitFailure(this.name, this.stack);
}

class XunitFailureResult {
  bool failure;
  List<XunitFailure> failures = [];

  XunitFailureResult();

  add(XunitFailure failure) {
    failures.add(failure);
  }
}

class XunitTestResult {
  int beginningTime;
  int endTime;
  XunitFailureResult error;
  String name;
  bool skipped = false;
  String skipReason;
  List<int> groupIDs;

  XunitTestResult(this.name, this.beginningTime, this.skipped, this.skipReason,
      this.groupIDs);
}

class XunitTestGroup {
  int errored = 0;
  int failed = 0;
  int skipped = 0;
  List<XunitTestResult> testResults = [];
  Map<int, XunitTestGroup> testSuites = {};
  int tests = 0;
  String name;
  int id;
  int parentID;

  XunitTestGroup(this.id, this.name, this.parentID) {
    this.errored = 0;
    this.failed = 0;
    this.skipped = 0;
    this.tests = 0;
  }

  add(XunitTestResult test) {
    testResults.add(test);
  }
}

Map testing = {};
Map<int, XunitTestGroup> groupMap = {};

handleGroup(Map outputLine) {
  var groupReference = outputLine["group"];
  if (outputLine["group"]["name"] != null) {
    groupMap[groupReference['id']] = groupReference["name"];
    String placeHolderName = groupReference["name"];
    placeHolderName = placeHolderName
        .substring(placeHolderName
                .indexOf(groupMap[outputLine['group']['parentID']].name) +
            groupMap[outputLine['group']['parentID']].name.length)
        .trimLeft();

    groupMap[groupReference['id']] = new XunitTestGroup(
        groupReference['id'], placeHolderName, groupReference['parentID']);
  }
  if (groupReference["name"] == null) {
    groupMap[groupReference['id']] =
        new XunitTestGroup(groupReference['id'], '', -1);
  }
}

handleTest(Map outputLine) {
  if (!outputLine["test"]["name"].contains('loading')) {
    groupMap[-1].tests++;
    String placeHolderName = outputLine["test"]["name"];
    placeHolderName = placeHolderName
        .substring(placeHolderName
                .indexOf(groupMap[outputLine["test"]["groupIDs"].last].name) +
            groupMap[outputLine["test"]["groupIDs"].last].name.length)
        .trimLeft();
    XunitTestResult testResult = new XunitTestResult(
        placeHolderName,
        outputLine['time'],
        outputLine["test"]['metadata']['skip'],
        outputLine["test"]['metadata']['skipReason'],
        outputLine["test"]['groupIDs']);
    testing[outputLine['test']['id']] = testResult;
    groupMap[outputLine["test"]['groupIDs'].last].add(testResult);
    if (testResult.skipped) {
      for (var i = 0; i < testResult.groupIDs.length; i++) {
        groupMap[testResult.groupIDs[i]].skipped++;
      }
      groupMap[-1].skipped++;
    }
  }
}

handleFailure() {}

handleTestId(Map outputLine) {
  if (testing.containsKey(outputLine["testID"])) {
    if (outputLine['type'] == 'testDone' && outputLine["result"] == "success") {
      XunitTestResult currentTest = testing[outputLine["testID"]];
      currentTest.endTime = outputLine['time'];
      for (var i = 0; i < currentTest.groupIDs.length; i++) {
        groupMap[currentTest.groupIDs[i]].tests++;
      }
    } else if (outputLine['type'] == 'testDone' &&
        outputLine["result"] == "failure") {
      XunitTestResult currentTest = testing[outputLine["testID"]];
      if (currentTest.error == null) {
        currentTest.error = new XunitFailureResult();
        currentTest.error.failure = true;
      }
      currentTest.endTime = outputLine['time'];
      for (var i = 1; i < currentTest.groupIDs.length; i++) {
        groupMap[currentTest.groupIDs[i]].failed++;
      }
      groupMap[-1].failed++;
    } else if (outputLine['type'] == 'testDone' &&
        outputLine["result"] == "error") {
      XunitTestResult currentTest = testing[outputLine["testID"]];
      if (currentTest.error == null) {
        currentTest.error = new XunitFailureResult();
        currentTest.error.failure = false;
      }
      currentTest.endTime = outputLine['time'];
      for (var i = 1; i < currentTest.groupIDs.length; i++) {
        groupMap[currentTest.groupIDs[i]].errored++;
      }
      groupMap[-1].errored++;
    } else if (outputLine['type'] == 'error' &&
        outputLine['isFailure'] == true) {
      XunitTestResult currentTest = testing[outputLine["testID"]];
      if (currentTest.error == null) {
        currentTest.error = new XunitFailureResult();
        currentTest.error.failure = true;
      }
      currentTest.error.failures.add(new XunitFailure(
          outputLine['error'].replaceAll('\n', ''),
          outputLine['stackTrace'].trimRight()));
    } else if (outputLine['type'] == 'error' &&
        outputLine['isFailure'] == false) {
      XunitTestResult currentTest = testing[outputLine["testID"]];
      if (currentTest.error == null) {
        currentTest.error = new XunitFailureResult();
        currentTest.error.failure = false;
      }
      currentTest.error.failures.add(new XunitFailure(
          outputLine['error'].replaceAll('\n', ''),
          outputLine['stackTrace'].trimRight()));
    }
  }
}

main() async {
  groupMap[-1] = new XunitTestGroup(-1, '', null);

  Process thing = await Process.start(
      'pub', ['run', 'test', 'test/action_test.dart', '--reporter', 'json']);

  thing.stdout.transform(UTF8.decoder).listen((String thingy1) {
    List<String> output = thingy1.split('\n');
    output.forEach((line) {
      if (line.isNotEmpty) {
        print(line);
        Map outputLine = JSON.decode(line);
        if (outputLine["group"] != null) {
          handleGroup(outputLine);
        }
        if (outputLine["test"] != null) {
          handleTest(outputLine);
        }
        if (outputLine["testID"] != null) {
          handleTestId(outputLine);
        }
      }
    });
  });

  await thing.exitCode;
  groupMap.forEach((key, XunitTestGroup value) {
    if (value.parentID != null) {
      groupMap[value.parentID].testSuites[value.id] = value;
    }
    if (value.parentID == -1) {
      groupMap[-1].testResults.addAll(value.testResults);
      value.testResults = [];
    }
  });

  List theList = groupMap.keys.toList();
  theList.sort();

  Map attempting = {};

  groupMap[-1].testSuites.forEach((key, value) {
    value.testSuites.forEach((key, value) {
      attempting[key] = value;
    });
  });

  groupMap[-1].testSuites = attempting;

  print('<testsuite name="All tests" tests="${groupMap.values.first.tests}" '
      'errors="${groupMap.values.first.errored}" failures="${groupMap.values.first.failed}" skipped="${groupMap.values.first.skipped}">');
  print(_formatTestResults(groupMap[theList[0]].testResults, depth: 1)
      .trimRight());
  String heirarchy = _formatXmlHierarchy(groupMap[theList[0]]).trimRight();
  if (heirarchy != '') {
    print(heirarchy);
  }
  print('</testsuite>'.trimLeft());
}

String _formatXmlHierarchy(XunitTestGroup xmlMap, {int depth: 1}) {
  String result = '';
  xmlMap.testSuites.keys.forEach((int elem) {
    if (xmlMap.testSuites[elem] is XunitTestGroup) {
      var heading = '';

      if (xmlMap.testSuites[elem].tests > 0) {
        heading += 'tests="${xmlMap.testSuites[elem].tests}" ';
      }
      if (xmlMap.testSuites[elem].failed > 0) {
        heading += 'failures="${xmlMap.testSuites[elem].failed}" ';
      }
      if (xmlMap.testSuites[elem].errored > 0) {
        heading += 'errors="${xmlMap.testSuites[elem].errored}" ';
      }
      if (xmlMap.testSuites[elem].skipped > 0) {
        heading += 'skipped="${xmlMap.testSuites[elem].skipped}" ';
      }
      heading = heading.trimRight();
      result += _indentLine(
          '<testsuite name="${xmlMap.testSuites[elem].name}" $heading>', depth);
      result += _formatTestResults(xmlMap.testSuites[elem].testResults,
          depth: depth + 1);
      result += _formatXmlHierarchy(xmlMap.testSuites[elem], depth: depth + 1);
      result += _indentLine('</testsuite>', depth);
    }
  });
  return result;
}

/// A method used to format individual testcases
String _formatTestResults(List list, {int depth}) {
  String results = '';
  list.forEach((XunitTestResult test) {
    String individualTest = '';
    String testName = _sanitizeXml(test.name);
    if (test.error == null && !test.skipped) {
      individualTest += _indentLine(
          '<testcase name=\"${testName}\" time=\"${test.endTime - test.beginningTime}\"> </testcase>',
          depth);
    } else {
      if (test.error != null) {
        individualTest += _indentLine('<testcase name=\"${testName}\">', depth);
        if (test.error.failure) {
          test.error.failures.forEach((XunitFailure testFailure) {
            individualTest += _indentLine(
                '<failure message="${_sanitizeXml(testFailure.name)}">',
                depth + 1);
            testFailure.stack.split('\n').forEach((line) {
              individualTest += _indentLine(line, depth + 2);
            });
            individualTest += _indentLine('</failure>', depth + 1);
          });
        } else {
          test.error.failures.forEach((XunitFailure testError) {
            individualTest += _indentLine(
                '<error message="${_sanitizeXml(testError.name)}">', depth + 1);
            testError.stack.split('\n').forEach((line) {
              individualTest += _indentLine(line, depth + 2);
            });
            individualTest += _indentLine('</error>', depth + 1);
          });
        }
        individualTest += _indentLine('</testcase>', depth);
      } else {
        individualTest += _indentLine('<testcase name=\"${testName}\">', depth);
        if (test.skipReason != null) {
          individualTest += _indentLine(
              '<skipped message="${_sanitizeXml(test.skipReason)}"/>',
              depth + 1);
        } else {
          individualTest += _indentLine('<skipped/>', depth + 1);
        }
        individualTest += _indentLine('</testcase>', depth);
      }
    }
    results += individualTest;
  });
  return results;
}

/// Indents a line by [depth] number of soft-tabs (2 space tabs). Also adds
/// a newline at the end of the line.
String _indentLine(String s, int depth) {
  if (depth <= 0) return s;
  return '  ' * depth + s + '\n';
}

String _sanitizeXml(String original) {
  String updated = original.replaceAll('&', '&amp;');
  updated = updated.replaceAll('<', '&lt;');
  updated = updated.replaceAll('>', '&gt;');
  updated = updated.replaceAll('"', '&quot;');
  return updated = updated.replaceAll("'", '&apos;');
}
