func capitalise(_ value: Any?) -> Any? {
  return stringify(value).capitalized
}

func uppercase(_ value: Any?) -> Any? {
  return stringify(value).uppercased()
}

func lowercase(_ value: Any?) -> Any? {
  return stringify(value).lowercased()
}

func defaultFilter(value: Any?, arguments: [Any?]) -> Any? {
  // value can be optional wrapping nil, so this way we check for underlying value
  if let value = value, String(describing: value) != "nil" {
    return value
  }

  for argument in arguments {
    if let argument = argument {
      return argument
    }
  }

  return nil
}

func joinFilter(value: Any?, arguments: [Any?]) throws -> Any? {
  guard arguments.count < 2 else {
    throw TemplateSyntaxError("'join' filter takes at most one argument")
  }

  let separator = stringify(arguments.first ?? "")

  if let value = value as? [Any] {
    return value
      .map(stringify)
      .joined(separator: separator)
  }

  return value
}

func splitFilter(value: Any?, arguments: [Any?]) throws -> Any? {
  guard arguments.count < 2 else {
    throw TemplateSyntaxError("'split' filter takes at most one argument")
  }

  let separator = stringify(arguments.first ?? " ")
  if let value = value as? String {
    return value.components(separatedBy: separator)
  }

  return value
}


func mapFilter(value: Any?, arguments: [Any?], context: Context) throws -> Any? {
  guard arguments.count >= 1 && arguments.count <= 2 else {
    throw TemplateSyntaxError("'map' filter takes one or two arguments")
  }

  let attribute = stringify(arguments[0])
  let variable = Variable("map_item.\(attribute)")
  let defaultValue = arguments.count == 2 ? arguments[1] : nil

  let resolveVariable = { (item: Any) throws -> Any in
    let result = try context.push(dictionary: ["map_item": item]) {
      try variable.resolve(context)
    }
    if let result = result { return result }
    else if let defaultValue = defaultValue { return defaultValue }
    else { return result as Any }
  }


  if let array = value as? [Any] {
    return try array.map(resolveVariable)
  } else {
    return try resolveVariable(value as Any)
  }
}

func compactFilter(value: Any?, arguments: [Any?], context: Context) throws -> Any? {
  guard arguments.count <= 1 else {
    throw TemplateSyntaxError("'compact' filter takes at most one argument")
  }

  guard var array = value as? [Any?] else { return value }

  if arguments.count == 1 {
    guard let mapped = try mapFilter(value: array, arguments: arguments, context: context) as? [Any?] else {
      return value
    }
    array = mapped
  }

  return array.flatMap({ item -> Any? in
    if let unwrapped = item, String(describing: unwrapped) != "nil" { return unwrapped }
    else { return nil }
  })
}

func filterFilter(value: Any?, arguments: [Any?], context: Context) throws -> Any? {
  guard arguments.count == 1 else {
    throw TemplateSyntaxError("'filter' filter takes one argument")
  }

  let attribute = stringify(arguments[0])
  let token = Token.block(value: attribute)
  let parser = TokenParser(tokens: [token], environment: context.environment)
  let expr = try IfExpressionParser(components: token.components(), tokenParser: parser).parse()

  if let array = value as? [Any] {
    return try array.filter {
      try context.push(dictionary: ["$0": $0]) {
        try expr.evaluate(context: context)
      }
    }
  }

  return value
}

