pragma Singleton
import QtQuick
import "."
import "BorderGeometry.js" as Geometry

QtObject {
  id: root

  function none() {
    return flat("transparent", 0)
  }

  function flat(color, width) {
    return {
      color: color || "transparent",
      widths: Geometry.parseWidthSpec(width, 0),
      gradient: { colors: [], angle: 0, enabled: false },
    }
  }

  function value(section, key) {
    var v = Color.shellValues[section + "." + key]
    return (v === undefined || v === null) ? "" : v
  }

  function valueOr(section, keys) {
    for (var i = 0; i < keys.length; i++) {
      var v = value(section, keys[i])
      if (String(v).length > 0) return v
    }
    return ""
  }

  function resolveValueRef(raw) {
    var s = String(raw || "").trim()
    var seen = {}
    while (s.match(/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/) && !seen[s]) {
      seen[s] = true
      var next = Color.shellValues[s]
      if (next === undefined || next === null || String(next).length === 0) break
      s = String(next).trim()
    }
    return s
  }

  function alpha(section, key, fallback) {
    var raw = value(section, key)
    if (String(raw).length === 0) return fallback
    var n = Number(raw)
    return isFinite(n) ? Geometry.clampAlpha(n) : fallback
  }

  function cssColor(color, opacity) {
    var a = opacity === undefined || opacity === null ? 1 : Geometry.clampAlpha(opacity)
    if (color && typeof color === "object" && color.r !== undefined) {
      if (typeof Qt !== "undefined" && Qt.rgba) {
        return Qt.rgba(color.r, color.g, color.b, (color.a === undefined ? 1 : color.a) * a)
      }
      return "#"
        + Geometry.padHex(color.r * 255)
        + Geometry.padHex(color.g * 255)
        + Geometry.padHex(color.b * 255)
        + Geometry.padHex((color.a === undefined ? 1 : color.a) * a * 255)
    }

    var s = String(color || "").trim()
    // Benannte Rollen -> Theme-Farben (ein Lookup statt if-Kette).
    var roleColor = {
      foreground: Color.foreground, text: Color.foreground,
      accent: Color.accent, urgent: Color.urgent, background: Color.background
    }[s.toLowerCase()]
    if (roleColor !== undefined) return cssColor(roleColor, a)
    if (s.toLowerCase() === "transparent") return "transparent"
    return Geometry.canonicalColor(s, a)
  }

  function resolvedGradient(raw, fallbackColor, opacity) {
    var s = String(raw || "").trim()
    if (s.length === 0) return { colors: [], angle: 0, enabled: false }

    var parts = s.split(/\s+/)
    var colors = []
    var angle = 0
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].match(/^-?\d+(?:\.\d+)?deg$/)) angle = Number(parts[i].replace(/deg$/, ""))
      else colors.push(cssColor(parts[i], opacity))
    }
    if (colors.length === 0) colors.push(cssColor(fallbackColor, opacity))
    return { colors: colors, angle: angle, enabled: colors.length > 1 }
  }

  function sameColor(a, b) {
    if (typeof Qt === "undefined" || !Qt.color) return String(a) === String(b)
    var ca = typeof a === "string" ? Qt.color(a) : a
    var cb = typeof b === "string" ? Qt.color(b) : b
    if (!ca || !cb || ca.r === undefined || cb.r === undefined) return String(a) === String(b)
    return Math.round(ca.r * 255) === Math.round(cb.r * 255)
      && Math.round(ca.g * 255) === Math.round(cb.g * 255)
      && Math.round(ca.b * 255) === Math.round(cb.b * 255)
      && Math.round((ca.a === undefined ? 1 : ca.a) * 255) === Math.round((cb.a === undefined ? 1 : cb.a) * 255)
  }

  function localOrSurfaceSpec(section, token, localColor, defaultColor, fallbackWidth, alphaKey) {
    if (!sameColor(localColor, defaultColor)) return flat(localColor, fallbackWidth)
    return surfaceSpec(section, token, localColor, fallbackWidth, alphaKey)
  }

  // Breiten-Schlüssel: "border" nutzt border-*, sonst token-* mit border-Fallback.
  function widthKeys(token, side) {
    var suffix = side ? "-" + side : ""
    if (token === "border") return ["border-width" + suffix]
    return [token + "-width" + suffix, "border-width" + suffix]
  }

  function surfaceWidths(section, token, fallbackWidth) {
    var widths = Geometry.parseWidthSpec(valueOr(section, widthKeys(token, "")), fallbackWidth)
    return Geometry.withSideOverrides(
      widths,
      valueOr(section, widthKeys(token, "top")),
      valueOr(section, widthKeys(token, "right")),
      valueOr(section, widthKeys(token, "bottom")),
      valueOr(section, widthKeys(token, "left"))
    )
  }

  function borderValue(raw, fallbackColor, opacity, legacyGradientRaw) {
    var fallback = cssColor(fallbackColor, opacity)
    var primaryRaw = String(raw || "").trim()
    var primary = resolvedGradient(primaryRaw.length > 0 ? primaryRaw : fallbackColor, fallbackColor, opacity)
    var color = primary.colors.length > 0 ? primary.colors[0] : fallback
    var gradient = primary.enabled ? primary : { colors: [], angle: 0, enabled: false }

    if (!gradient.enabled && String(legacyGradientRaw || "").trim().length > 0) {
      var legacy = resolvedGradient(legacyGradientRaw, color, opacity)
      if (legacy.enabled) gradient = legacy
    }

    return { color: color, gradient: gradient }
  }

  function surfaceSpec(section, token, fallbackColor, fallbackWidth, alphaKey) {
    var opacity = alpha(section, alphaKey || token + "-alpha", 1.0)
    var gradientKeys = token === "border" ? ["border-gradient"] : [token + "-gradient", "border-gradient"]
    var legacyGradientRaw = valueOr(section, gradientKeys)
    var resolved = borderValue(resolveValueRef(value(section, token)), fallbackColor, opacity, legacyGradientRaw)

    return {
      color: resolved.color,
      widths: surfaceWidths(section, token, fallbackWidth),
      gradient: resolved.gradient,
    }
  }


  function controlPrefix(state) {
    if (state === "hover" || state === "hot") return "hover-cursor"
    return state || "normal"
  }

  function controlColor(prefix, foreground, accent, urgent) {
    // Tabellengesteuert statt if-Kette — neue States nur hier ergänzen.
    var fn = {
      focus: Style.focusStateColor,
      "hover-cursor": Style.hoverStateColor,
      selected: Style.selectedStateColor
    }[prefix] || Style.normalStateColor
    return fn(foreground, accent, urgent)
  }

  function controlAlpha(prefix) {
    var table = {
      focus: Style.focusBorderAlpha,
      "hover-cursor": Style.hoverBorderAlpha,
      selected: Style.selectedBorderAlpha
    }
    return table[prefix] !== undefined ? table[prefix] : Style.normalBorderAlpha
  }

  function controlFallbackWidth(prefix) {
    var widths = {
      focus: Style.focusBorderWidth,
      "hover-cursor": Style.hoverBorderWidth,
      selected: Style.selectedBorderWidth
    }
    return widths[prefix] !== undefined ? widths[prefix] : Style.normalBorderWidth
  }

  function controlWidths(state) {
    var prefix = controlPrefix(state)
    var fallbackWidth = controlFallbackWidth(prefix)
    var base = Style.styleOverrides[prefix + "-border-width"]
    var widths = Geometry.parseWidthSpec(base, fallbackWidth)
    return Geometry.withSideOverrides(
      widths,
      Style.styleOverrides[prefix + "-border-width-top"],
      Style.styleOverrides[prefix + "-border-width-right"],
      Style.styleOverrides[prefix + "-border-width-bottom"],
      Style.styleOverrides[prefix + "-border-width-left"]
    )
  }

  function controlHasWidth(state) {
    return Geometry.maxWidth(controlWidths(state)) > 0
  }

  function controlSpec(state, foreground, accent, urgent) {
    var prefix = controlPrefix(state)
    var resolved = borderValue(
      Style.styleOverrides[prefix + "-border"],
      controlColor(prefix, foreground, accent, urgent),
      controlAlpha(prefix),
      Style.styleOverrides[prefix + "-border-gradient"]
    )

    return { color: resolved.color, widths: controlWidths(prefix), gradient: resolved.gradient }
  }

  function withWidth(spec, width) {
    if (!spec) return flat("transparent", 0)
    return { color: spec.color, gradient: spec.gradient, widths: Geometry.parseWidthSpec(width, 0) }
  }

  function isNone(spec) { return !spec || Geometry.maxWidth(spec.widths) <= 0 }
  function needsOverlay(spec) { return Geometry.needsOverlay(spec) }
  function canUseNative(spec) { return Geometry.canUseNative(spec) }
  function top(spec) { return spec && spec.widths ? spec.widths.top : 0 }
  function right(spec) { return spec && spec.widths ? spec.widths.right : 0 }
  function bottom(spec) { return spec && spec.widths ? spec.widths.bottom : 0 }
  function left(spec) { return spec && spec.widths ? spec.widths.left : 0 }
  function uniformWidth(spec) { return spec && spec.widths ? spec.widths.top : 0 }
  function color(spec) { return spec ? spec.color : "transparent" }
}
