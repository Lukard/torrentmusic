import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'flows/error_handling_test.dart';
import 'flows/navigation_flow_test.dart';
import 'flows/playback_flow_test.dart';
import 'flows/queue_flow_test.dart';
import 'flows/search_flow_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Navigation', navigationFlowTests);
  group('Search', searchFlowTests);
  group('Playback', playbackFlowTests);
  group('Queue', queueFlowTests);
  group('Error Handling', errorHandlingTests);
}
