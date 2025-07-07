import 'package:flutter/material.dart';
import 'dart:ui';

/// Helper function to create gradient borders for 3D effect
Widget _createGradientBorder({
  required Widget child,
  required BorderRadius borderRadius,
  required bool isDarkMode,
  double borderWidth = 1.5,
}) {
  return Container(
    decoration: BoxDecoration(
      borderRadius: borderRadius,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDarkMode
            ? [
                Colors.black.withOpacity(0.08), // Subtle black at top
                Colors.black.withOpacity(0.05), // Medium subtle
                Colors.white.withOpacity(0.05), // Subtle white at bottom
              ]
            : [
                Colors.black.withOpacity(0.08), // Subtle black at top
                Colors.black.withOpacity(0.05), // Medium subtle
                Colors.white.withOpacity(0.08), // Subtle white at bottom
              ],
        stops: const [0.0, 0.5, 1.0],
      ),
    ),
    child: Container(
      margin: EdgeInsets.all(borderWidth),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius.topLeft.x - borderWidth),
      ),
      child: child,
    ),
  );
}

/// A customizable glassmorphism container widget
class GlassmorphismContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final double blur;
  final double opacity;
  final Color borderColor;
  final double borderWidth;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final AlignmentGeometry alignment;
  final Color backgroundColor;

  const GlassmorphismContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.blur = 20,
    this.opacity = 0.2,
    this.borderColor = Colors.white,
    this.borderWidth = 1.5,
    this.padding = const EdgeInsets.all(20),
    this.margin = const EdgeInsets.all(0),
    this.alignment = Alignment.center,
    this.backgroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return Container(
      width: width,
      height: height,
      margin: margin,
      child: _createGradientBorder(
        borderRadius: borderRadius,
        isDarkMode: isDarkMode,
        borderWidth: borderWidth,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius.topLeft.x - borderWidth),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Container(
              alignment: alignment,
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius.topLeft.x - borderWidth),
                color: backgroundColor.withOpacity(opacity * 0.08),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A glassmorphism card widget
class GlassmorphismCard extends StatelessWidget {
  final Widget child;
  final double elevation;
  final BorderRadius borderRadius;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final VoidCallback? onTap;
  final bool isDark;

  const GlassmorphismCard({
    super.key,
    required this.child,
    this.elevation = 8,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.all(8),
    this.onTap,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark || isDark;
    
    return Container(
      margin: margin,
      child: _createGradientBorder(
        borderRadius: borderRadius,
        isDarkMode: isDarkMode,
        borderWidth: 1.5,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius.topLeft.x - 1.5),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(borderRadius.topLeft.x - 1.5),
                child: Container(
                  padding: padding,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(borderRadius.topLeft.x - 1.5),
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.08)
                        : Colors.white.withOpacity(0.05), // Much more transparent
                    boxShadow: [
                      BoxShadow(
                        color: isDarkMode 
                          ? Colors.black.withOpacity(0.2)
                          : Colors.grey.withOpacity(0.05), // Much lighter shadow
                        blurRadius: elevation,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A glassmorphism snackbar widget
class GlassmorphismSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    IconData? icon,
    Duration duration = const Duration(seconds: 2),
    Color? backgroundColor,
    Color? textColor,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 100,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: _createGradientBorder(
              borderRadius: BorderRadius.circular(16),
              isDarkMode: isDarkMode,
              borderWidth: 1.5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14.5),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14.5),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDarkMode
                            ? [
                                Colors.black.withOpacity(0.6),
                                Colors.black.withOpacity(0.3),
                                Colors.white.withOpacity(0.1),
                              ]
                            : [
                                Colors.black.withOpacity(0.4),
                                Colors.black.withOpacity(0.2),
                                Colors.white.withOpacity(0.8),
                              ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDarkMode 
                            ? Colors.black.withOpacity(0.4)
                            : Colors.black.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(
                            icon,
                            color: textColor ?? Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Text(
                            message,
                            style: TextStyle(
                              color: textColor ?? Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    
    overlay.insert(overlayEntry);
    
    Future.delayed(duration, () {
      overlayEntry.remove();
    });
  }
}

/// A glassmorphism app bar
class GlassmorphismAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final double elevation;
  final Color? backgroundColor;

  const GlassmorphismAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.elevation = 0,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDarkMode
                  ? [
                      Colors.black.withOpacity(0.2),
                      Colors.black.withOpacity(0.1),
                    ]
                  : [
                      Colors.white.withOpacity(0.3),
                      Colors.white.withOpacity(0.1),
                    ],
            ),
            border: Border(
              bottom: BorderSide(
                color: isDarkMode 
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.1),
                width: 0.5,
              ),
            ),
          ),
          child: AppBar(
            title: Text(title),
            actions: actions,
            leading: leading,
            centerTitle: centerTitle,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// A glassmorphism bottom navigation bar
class GlassmorphismBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<BottomNavigationBarItem> items;
  final bool showLabels;
  final Color? selectedItemColor;
  final Color? unselectedItemColor;
  final BottomNavigationBarType? type;
  final bool? showSelectedLabels;
  final bool? showUnselectedLabels;
  final Color? backgroundColor;
  final double? elevation;
  final double? iconSize;

  const GlassmorphismBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.showLabels = true,
    this.selectedItemColor,
    this.unselectedItemColor,
    this.type,
    this.showSelectedLabels,
    this.showUnselectedLabels,
    this.backgroundColor,
    this.elevation,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return Container(
      height: 56,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDarkMode
                    ? [
                        Colors.black.withOpacity(0.2),
                        Colors.black.withOpacity(0.1),
                      ]
                    : [
                        Colors.white.withOpacity(0.3),
                        Colors.white.withOpacity(0.1),
                      ],
              ),
              border: Border.all(
                color: isDarkMode 
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.1),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(items.length, (index) {
                final item = items[index];
                final isSelected = index == currentIndex;
                final icon = isSelected ? (item.activeIcon ?? item.icon) : item.icon;
                
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(index),
                    child: SizedBox(
                      height: 60, // 56'dan 60'a büyütüldü (orantılı)
                      child: Center(
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            iconTheme: IconThemeData(
                              color: isSelected 
                                ? (selectedItemColor ?? (isDarkMode ? Colors.white : Colors.black))
                                : (unselectedItemColor ?? (isDarkMode ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7))),
                            ),
                          ),
                          child: icon,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

/// A glassmorphism floating action button
class GlassmorphismFAB extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double size;

  const GlassmorphismFAB({
    super.key,
    required this.onPressed,
    required this.child,
    this.backgroundColor,
    this.foregroundColor,
    this.size = 56.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: isDarkMode 
              ? Colors.black.withOpacity(0.3)
              : Colors.grey.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isDarkMode 
                  ? Colors.white.withOpacity(0.2)
                  : Colors.white.withOpacity(0.3),
                width: 1,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (backgroundColor ?? theme.primaryColor).withOpacity(0.8),
                  (backgroundColor ?? theme.primaryColor).withOpacity(0.6),
                ],
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(size / 2),
                child: SizedBox(
                  width: size,
                  height: size,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A glassmorphism button
class GlassmorphismButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final EdgeInsets padding;
  final BorderRadius borderRadius;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double elevation;

  const GlassmorphismButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.backgroundColor,
    this.foregroundColor,
    this.elevation = 4,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: isDarkMode 
              ? Colors.black.withOpacity(0.3)
              : Colors.grey.withOpacity(0.2),
            blurRadius: elevation,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              border: Border.all(
                color: isDarkMode 
                  ? Colors.white.withOpacity(0.2)
                  : Colors.white.withOpacity(0.3),
                width: 1,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (backgroundColor ?? theme.primaryColor).withOpacity(0.8),
                  (backgroundColor ?? theme.primaryColor).withOpacity(0.6),
                ],
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: borderRadius,
                child: Container(
                  padding: padding,
                  child: DefaultTextStyle(
                    style: TextStyle(
                      color: foregroundColor ?? Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 