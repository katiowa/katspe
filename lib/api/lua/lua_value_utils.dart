/// Lua's empty table (`{}`) is ambiguous between an empty array and an
/// empty object — nothing about it says which the author meant. Once
/// converted to Dart, a *non-empty* array-like table becomes a proper
/// `List`, but an *empty* one has no keys to inspect and comes back as
/// an empty `Map` instead (there's no evidence either way, so the
/// conversion falls back to the more general shape).
///
/// Anything reading a list back from a Lua `invoke`/`render` result —
/// `list_markers`' `markers`, `poi_categories`' `categories`, a
/// descriptor's `children`, and so on — has to go through this instead
/// of a bare `as List?` cast, or the very first time that list happens
/// to be empty (which is exactly the case at boot, before anything's
/// been imported) throws a type error instead of just... being empty.
List<dynamic> asLuaList(dynamic value) {
  if (value is List) return value;
  return const [];
}
