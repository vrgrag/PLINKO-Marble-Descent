/// Which experience the shell locked onto for this install.
///
/// - [shell]  → returning user was routed to the WebView last time
/// - [native] → returning user was routed to the native game last time
/// - [fresh]  → first launch, undecided
enum RuntimeMode {
  shell,
  native,
  fresh;

  static RuntimeMode read(String? raw) {
    switch (raw) {
      case 'shell':
        return RuntimeMode.shell;
      case 'native':
        return RuntimeMode.native;
      default:
        return RuntimeMode.fresh;
    }
  }

  String write() => name;
}
