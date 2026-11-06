import java.nio.file.Files;
import java.nio.file.Path;
import com.google.firebase.rules.lang.FirebaseRulesProtoCompiler;
import com.google.firebase.rules.lang.common.FirebaseRulesLangOptions;
import com.google.firebase.rules.v1.Source;
import com.google.firebase.rules.v1.File;

/** Offline syntax/type check using the same compiler bundled in the emulator.
 * Does not open sockets, contact production, or replace authorization tests.
 * java --class-path ~/.cache/firebase/emulators/cloud-firestore-emulator-v1.19.8.jar \
 *   firebase/tests/CompileRules.java firebase/firestore.rules
 */
class CompileRules {
  public static void main(String[] args) throws Exception {
    if (args.length != 1) throw new IllegalArgumentException("Provide the local rules file.");
    var contents = Files.readString(Path.of(args[0]));
    var source = Source.newBuilder().addFiles(File.newBuilder()
        .setName("firestore.rules").setContent(contents)).build();
    var result = FirebaseRulesProtoCompiler.createStandalone(
        FirebaseRulesLangOptions.builder().allowTernaryOperator(true).build()).compile(source);
    for (var issue : result.getIssues()) System.out.println(issue);
    if (result.hasCompilationError()) System.exit(1);
    // Compile every literal RE2 expression too (the language compiler does not
    // execute matches). This uses the emulator's RE2 engine, not Java regex.
    var matches = java.util.regex.Pattern.compile("\\.matches\\('([^']*)'\\)").matcher(contents);
    int patterns = 0;
    while (matches.find()) {
      com.google.re2j.Pattern.compile(matches.group(1).replace("\\\\", "\\"));
      patterns++;
    }
    System.out.println(patterns + " literal security-rule RE2 expressions compiled.");
    System.out.println("Firestore rules compiled offline; authorization/emulator integration tests still required.");
  }
}
