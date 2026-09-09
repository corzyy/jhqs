function nearestDropTarget(candidates, point, vertical) {
    var rows = Array.isArray(candidates) ? candidates : []
    var axis = vertical ? Number(point && point.y) : Number(point && point.x)
    if (!isFinite(axis)) return null

    var best = null
    var bestDistance = Infinity
    for (var i = 0; i < rows.length; i++) {
        var row = rows[i]
        if (!row || !row.slot) continue

        var start = Number(vertical ? row.y : row.x)
        var size = Number(vertical ? row.height : row.width)
        if (!isFinite(start) || !isFinite(size) || size <= 0) continue

        var beforeDistance = Math.abs(axis - start)
        var afterDistance = Math.abs(axis - (start + size))
        var after = afterDistance < beforeDistance
        var distance = after ? afterDistance : beforeDistance
        if (distance < bestDistance) {
            best = { slot: row.slot, after: after, emptySection: row.emptySection, emptyIndex: row.emptyIndex }
            bestDistance = distance
        }
    }
    return best
}
