import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? timerText;
  final Color? timerColor;
  final List<Widget>? actions;
  final bool isDimmed;

  const CustomAppBar({
    Key? key,
    required this.title,
    this.timerText,
    this.timerColor,
    this.actions,
    this.isDimmed = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    
    return PreferredSize(
       
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Center(
        child: FractionallySizedBox(
          child: Container(
            decoration: BoxDecoration(
              color: isDimmed
                  ? Colors.black.withOpacity(0.5)
                  : const Color.fromARGB(255, 161, 111, 241),
              borderRadius: const BorderRadius.all(Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: AppBar(
              backgroundColor: isDimmed
                  ? Colors.black.withOpacity(0.5)
                  : const Color.fromARGB(255, 161, 111, 241),
              elevation: 0,
              title: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Vazir',
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              actions: actions ?? [],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}