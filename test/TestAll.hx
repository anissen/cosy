import sys.FileSystem;
import sys.io.File;
import lox.Lox;
import utest.Assert;
import utest.Runner;
import utest.ui.Report;

class TestAll {
  public static function main() {
    var runner = new Runner();
    runner.addCase(new TestFiles());
    runner.addCase(new TestTypes());
    Report.create(runner);
    runner.run();
  }
}

class TestFiles extends utest.Test {
    function testFiles() {
        var scriptsDir = 'test/scripts/';
        for (file in FileSystem.readDirectory(scriptsDir)) {
            if (!StringTools.endsWith(file, '.lox')) continue;

            trace('Testing $file');
            var path = scriptsDir + file;
            var prettyPrint = false;
            if (FileSystem.exists(path + '.options')) {
                var options = File.getContent(path + '.options');
                prettyPrint = (options.indexOf('--prettyprint') > -1);
            }
            var script = File.getContent(path);
            var output = StringTools.rtrim(File.getContent('$path.stdout'));
            Assert.equals(output, Lox.test(script, prettyPrint));
        }
    }
}

class TestTypes extends utest.Test {
    function testBoolean() {
        Assert.equals('true', Lox.test('var b = true; print b;'));
        Assert.equals('false', Lox.test('var b = false; print b;'));
    }

    function testNumber() {
        Assert.equals('0', Lox.test('var i = 0; print i;'));
        Assert.equals('100', Lox.test('var i = 100; print i;'));
        Assert.equals('7.5', Lox.test('var i = 7.5; print i;'));
        Assert.equals('-7.5', Lox.test('var i = -7.5; print i;'));
    }

    function testString() {
        Assert.equals('', Lox.test('var s = ""; print s;'));
        Assert.equals('hello', Lox.test('var s = "hello"; print s;'));
        Assert.equals('hello\nworld', Lox.test('var s = "hello\nworld"; print s;'));
    }
}
