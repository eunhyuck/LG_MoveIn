import 'package:flutter/material.dart';
import 'package:lg_move_in/screens/thinq_menu_tab.dart';
import 'package:lg_move_in/screens/move_in_hub_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://fdugmidipljoesfsshzn.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZkdWdtaWRpcGxqb2VzZnNzaHpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA5ODMwMjksImV4cCI6MjA5NjU1OTAyOX0.pxTJHby6s_dvz7K8rciy4efdykaCdZ7BRXEMW44POrw',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LG ThinQ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF4F5F8),
        fontFamily: 'Pretendard',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE6007E),
          primary: const Color(0xFFE6007E),
          secondary: const Color(0xFF2B2A27),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF2B2A27),
          ),
          bodyLarge: TextStyle(color: Color(0xFF2B2A27)),
          bodyMedium: TextStyle(color: Color(0xFF5F5D58)),
        ),
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 3; // Default to 'Menu' tab as in screenshot

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const Center(child: Text("홈 화면", style: TextStyle(fontSize: 18))),
          const Center(child: Text("디바이스 화면", style: TextStyle(fontSize: 18))),
          const Center(child: Text("케어 화면", style: TextStyle(fontSize: 18))),
          ThinQMenuTab(
            onNavigateToMoveIn: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MoveInHubScreen(),
                ),
              ).then((_) => setState(() {}));
            },
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE2E4E8), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF2B2A27),
          unselectedItemColor: const Color(0xFF8A877F),
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: [
            BottomNavigationBarItem(
              icon: Icon(_currentIndex == 0 ? Icons.home : Icons.home_outlined),
              label: '홈',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                _currentIndex == 1 ? Icons.widgets : Icons.widgets_outlined,
              ),
              label: '디바이스',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                _currentIndex == 2 ? Icons.insights : Icons.insights_outlined,
              ),
              label: '케어',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _currentIndex == 3
                      ? const Color(0xFF2B2A27)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.menu,
                  color: _currentIndex == 3
                      ? Colors.white
                      : const Color(0xFF8A877F),
                  size: 20,
                ),
              ),
              label: '메뉴',
            ),
          ],
        ),
      ),
    );
  }
}
