import 'package:flutter_test/flutter_test.dart';
import 'package:housecontrol_pi/main.dart';

void main() {
  testWidgets('首頁顯示運動控制台與燈光控制', (tester) async {
    await tester.pumpWidget(const HouseControlApp());

    expect(find.text('HOME CONTROL'), findsOneWidget);
    expect(find.text('客廳即時狀態'), findsOneWidget);
    expect(find.text('客廳主燈'), findsOneWidget);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(find.text('選擇音樂'), findsOneWidget);
  });

  testWidgets('底部導覽可開啟溫濕度歷史圖表', (tester) async {
    await tester.pumpWidget(const HouseControlApp());
    await tester.tap(find.text('活動'));
    await tester.pumpAndSettle();

    expect(find.text('活動紀錄'), findsOneWidget);
    expect(find.text('環境變化'), findsOneWidget);
  });
}
