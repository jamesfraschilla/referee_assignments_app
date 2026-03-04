enum ScreenSize { compact, medium, expanded }

ScreenSize screenSizeForWidth(double width) {
  if (width < 600) {
    return ScreenSize.compact;
  }
  if (width < 1024) {
    return ScreenSize.medium;
  }
  return ScreenSize.expanded;
}
