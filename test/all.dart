library globbing.all_tests;

import "test_glob_filter.dart" as test_glob_filter;
import "test_glob_lister.dart" as test_glob_lister;
import "test_glob_parser.dart" as test_glob_parser;
import "test_globbing.dart" as test_globbing;

main() {
  defineTests();
}

void defineTests() {
 test_glob_filter.defineTests();
 test_glob_lister.defineTests();
 test_glob_parser.defineTests();
 test_globbing.defineTests();
}
