.pragma library

// Pure draft-model, validation, and geometry helpers for Displays. No function
// in this file talks to Hyprland, writes files, or mutates an input object.

var MinScale = 0.25;
var MaxScale = 4.0;
var ExtremeScaleLow = 0.75;
var ExtremeScaleHigh = 2.5;
var RefreshTolerance = 0.1;

function finiteNumber(value) {
    return typeof value === "number" && Number.isFinite(value);
}

function quarterTurn(transform) {
    return [1, 3, 5, 7].includes(transform);
}

function isMirror(rule) {
    var target = String(rule.mirrorOf ?? "");
    return target.length > 0 && target !== "none";
}

function isExtended(rule) {
    return Boolean(rule.enabled) && !isMirror(rule);
}

function clone(value) {
    return JSON.parse(JSON.stringify(value));
}

function modeFromMonitor(monitor) {
    return {
        width: monitor.width,
        height: monitor.height,
        refreshRate: monitor.refreshRate,
    };
}

function capabilitiesFromMonitors(monitors) {
    var capabilities = {};
    for (const monitor of monitors) {
        capabilities[monitor.name] = {
            connected: true,
            modes: (monitor.modes ?? []).map(mode => ({
                width: mode.width,
                height: mode.height,
                refreshRate: mode.refreshRate,
                raw: mode.raw,
            })),
        };
    }
    return capabilities;
}

function draftFromMonitors(monitors) {
    return {
        rules: monitors.map(monitor => ({
            output: monitor.name,
            enabled: monitor.enabled,
            mode: modeFromMonitor(monitor),
            x: monitor.x,
            y: monitor.y,
            scale: monitor.scale,
            transform: monitor.transform,
            mirrorOf: monitor.mirrorOf === "none" ? "" : monitor.mirrorOf,
            // `monitors all` exposes active VRR, not configured VRR policy.
            // Keep the draft explicit about that unknown rather than guessing.
            vrr: null,
        })),
        monitorCapabilities: capabilitiesFromMonitors(monitors),
    };
}

function effectiveLogicalSize(rule) {
    if (!rule || !rule.mode || !finiteNumber(rule.mode.width) || !finiteNumber(rule.mode.height)
        || !finiteNumber(rule.scale) || rule.scale <= 0 || ![0, 1, 2, 3, 4, 5, 6, 7].includes(rule.transform)) {
        return null;
    }

    var pixelWidth = quarterTurn(rule.transform) ? rule.mode.height : rule.mode.width;
    var pixelHeight = quarterTurn(rule.transform) ? rule.mode.width : rule.mode.height;
    return {
        width: pixelWidth / rule.scale,
        height: pixelHeight / rule.scale,
    };
}

// x/y are always Hyprland logical-layout coordinates. width/height from the
// selected mode are physical pixels; transform swaps them before scale divides.
function logicalRect(rule) {
    var size = effectiveLogicalSize(rule);
    if (!size || !finiteNumber(rule.x) || !finiteNumber(rule.y))
        return null;
    return {
        output: rule.output,
        x: rule.x,
        y: rule.y,
        width: size.width,
        height: size.height,
        right: rule.x + size.width,
        bottom: rule.y + size.height,
    };
}

function rectFor(value) {
    return value && finiteNumber(value.right) && finiteNumber(value.bottom)
        ? value
        : logicalRect(value);
}

function layoutBounds(rules) {
    var rects = rules.filter(isExtended).map(logicalRect).filter(Boolean);
    if (rects.length === 0)
        return null;
    var left = rects[0].x;
    var top = rects[0].y;
    var right = rects[0].right;
    var bottom = rects[0].bottom;
    for (const rect of rects.slice(1)) {
        left = Math.min(left, rect.x);
        top = Math.min(top, rect.y);
        right = Math.max(right, rect.right);
        bottom = Math.max(bottom, rect.bottom);
    }
    return { x: left, y: top, width: right - left, height: bottom - top, right, bottom };
}

function overlaps(first, second) {
    var a = rectFor(first);
    var b = rectFor(second);
    if (!a || !b)
        return false;
    return a.x < b.right && a.right > b.x && a.y < b.bottom && a.bottom > b.y;
}

function rangesTouchOrOverlap(aStart, aEnd, bStart, bEnd, tolerance) {
    return aStart <= bEnd + tolerance && aEnd + tolerance >= bStart;
}

function isAdjacent(first, second, tolerance) {
    var a = rectFor(first);
    var b = rectFor(second);
    var gap = tolerance ?? 1;
    if (!a || !b)
        return false;
    var verticallyAligned = rangesTouchOrOverlap(a.y, a.bottom, b.y, b.bottom, gap);
    var horizontallyAligned = rangesTouchOrOverlap(a.x, a.right, b.x, b.right, gap);
    return (verticallyAligned && (Math.abs(a.right - b.x) <= gap || Math.abs(b.right - a.x) <= gap))
        || (horizontallyAligned && (Math.abs(a.bottom - b.y) <= gap || Math.abs(b.bottom - a.y) <= gap));
}

function normalizeLayout(rules) {
    var bounds = layoutBounds(rules);
    if (!bounds)
        return clone(rules);
    return rules.map(rule => {
        var next = clone(rule);
        if (isExtended(rule)) {
            next.x = rule.x - bounds.x;
            next.y = rule.y - bounds.y;
        }
        return next;
    });
}

function visualAspectRatio(rule) {
    var size = effectiveLogicalSize(rule);
    return size && size.height > 0 ? size.width / size.height : null;
}

function monitorCenter(rule) {
    var rect = logicalRect(rule);
    return rect ? { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 } : null;
}

// Returns possible edge-alignment positions. The caller chooses whether to use
// one; this helper never changes the dragged rule or rearranges other outputs.
function snapCandidatePositions(draggedRule, rules, tolerance) {
    var dragged = logicalRect(draggedRule);
    var gap = tolerance ?? 16;
    if (!dragged)
        return [];

    var candidates = [];
    for (const targetRule of rules) {
        if (!isExtended(targetRule) || targetRule.output === draggedRule.output)
            continue;
        var target = logicalRect(targetRule);
        if (!target)
            continue;
        var horizontal = [
            [target.x, "left-left"], [target.right - dragged.width, "right-right"],
            [target.x - dragged.width, "right-left"], [target.right, "left-right"],
        ];
        var vertical = [
            [target.y, "top-top"], [target.bottom - dragged.height, "bottom-bottom"],
            [target.y - dragged.height, "bottom-top"], [target.bottom, "top-bottom"],
        ];
        for (const candidate of horizontal) {
            if (Math.abs(dragged.x - candidate[0]) <= gap)
                candidates.push({ axis: "x", value: candidate[0], kind: candidate[1], target: target.output });
        }
        for (const candidate of vertical) {
            if (Math.abs(dragged.y - candidate[0]) <= gap)
                candidates.push({ axis: "y", value: candidate[0], kind: candidate[1], target: target.output });
        }
    }
    return candidates;
}

function issue(severity, code, message, outputs) {
    return { severity, code, message, outputs: outputs ?? [] };
}

function matchingMode(mode, advertisedModes) {
    return advertisedModes.some(advertised => advertised.width === mode.width
        && advertised.height === mode.height
        && Math.abs(advertised.refreshRate - mode.refreshRate) < RefreshTolerance);
}

function hasMirrorCycle(ruleByOutput, start) {
    var seen = new Set();
    var current = start;
    while (current && ruleByOutput[current] && isMirror(ruleByOutput[current])) {
        if (seen.has(current))
            return true;
        seen.add(current);
        current = ruleByOutput[current].mirrorOf;
    }
    return false;
}

function validateDraft(draft) {
    var rules = draft?.rules ?? [];
    var capabilities = draft?.monitorCapabilities ?? {};
    var errors = [];
    var warnings = [];
    var ruleByOutput = {};

    for (const rule of rules) {
        if (!rule.output)
            errors.push(issue("error", "missing-output", "A monitor rule has no output name."));
        else if (ruleByOutput[rule.output])
            errors.push(issue("error", "duplicate-output", `Output ${rule.output} appears more than once.`, [rule.output]));
        else
            ruleByOutput[rule.output] = rule;
    }

    var usableOutputs = rules.filter(isExtended);
    if (usableOutputs.length === 0)
        errors.push(issue("error", "no-usable-output", "At least one enabled, non-mirrored output is required."));

    for (const rule of rules) {
        var output = rule.output || "(unnamed)";
        var mode = rule.mode;
        if (!finiteNumber(rule.x) || !finiteNumber(rule.y))
            errors.push(issue("error", "invalid-position", `Output ${output} has non-finite layout coordinates.`, [output]));
        if (!finiteNumber(rule.scale) || rule.scale < MinScale || rule.scale > MaxScale)
            errors.push(issue("error", "invalid-scale", `Output ${output} scale must be within ${MinScale}–${MaxScale}.`, [output]));
        else if (rule.scale < ExtremeScaleLow || rule.scale > ExtremeScaleHigh)
            warnings.push(issue("warning", "extreme-scale", `Output ${output} uses an unusual scale (${rule.scale}).`, [output]));
        else if (rule.mode && finiteNumber(rule.mode.width) && finiteNumber(rule.mode.height)) {
            var logicalSize = effectiveLogicalSize(rule);
            if (logicalSize && (Math.abs(logicalSize.width - Math.round(logicalSize.width)) > 0.0001
                || Math.abs(logicalSize.height - Math.round(logicalSize.height)) > 0.0001)) {
                errors.push(issue("error", "invalid-logical-pixel-grid", `Output ${output} scale does not produce whole logical pixels for its selected mode.`, [output]));
            }
        }
        if (![0, 1, 2, 3, 4, 5, 6, 7].includes(rule.transform))
            errors.push(issue("error", "invalid-transform", `Output ${output} has an invalid transform.`, [output]));

        if (isExtended(rule)) {
            if (!mode || !finiteNumber(mode.width) || mode.width <= 0 || !finiteNumber(mode.height) || mode.height <= 0
                || !finiteNumber(mode.refreshRate) || mode.refreshRate <= 0) {
                errors.push(issue("error", "invalid-mode", `Enabled output ${output} needs a valid mode.`, [output]));
            } else {
                var advertised = capabilities[rule.output]?.modes;
                if (Array.isArray(advertised) && advertised.length > 0 && !matchingMode(mode, advertised))
                    errors.push(issue("error", "mode-not-advertised", `Selected mode for ${output} is not advertised by that output.`, [output]));
                else if (!Array.isArray(advertised) || advertised.length === 0)
                    warnings.push(issue("warning", "mode-not-verifiable", `Selected mode for ${output} cannot be verified against advertised modes.`, [output]));
                if (mode.refreshRate < 30 || mode.refreshRate > 360)
                    warnings.push(issue("warning", "unusual-refresh-rate", `Output ${output} uses an unusual refresh rate (${mode.refreshRate} Hz).`, [output]));
            }
        }

        if (isMirror(rule)) {
            var target = ruleByOutput[rule.mirrorOf];
            if (!target)
                errors.push(issue("error", "mirror-target-missing", `Mirror target ${rule.mirrorOf} for ${output} does not exist.`, [output, rule.mirrorOf]));
            else {
                if (!target.enabled)
                    errors.push(issue("error", "mirror-target-disabled", `Mirror target ${rule.mirrorOf} for ${output} is disabled.`, [output, rule.mirrorOf]));
                if (rule.mirrorOf === rule.output)
                    errors.push(issue("error", "mirror-self", `Output ${output} cannot mirror itself.`, [output]));
                if (target.mode && mode && (target.mode.width / target.mode.height !== mode.width / mode.height
                    || target.mode.width !== mode.width || target.mode.height !== mode.height)) {
                    warnings.push(issue("warning", "mirror-mode-mismatch", `Mirror ${output} and ${rule.mirrorOf} use different modes or aspect ratios.`, [output, rule.mirrorOf]));
                }
            }
        }
    }

    for (const output of Object.keys(ruleByOutput)) {
        if (isMirror(ruleByOutput[output]) && hasMirrorCycle(ruleByOutput, output))
            errors.push(issue("error", "mirror-cycle", `Mirror cycle includes ${output}.`, [output]));
    }

    var extended = rules.filter(isExtended);
    for (var first = 0; first < extended.length; first++) {
        for (var second = first + 1; second < extended.length; second++) {
            if (overlaps(extended[first], extended[second]))
                warnings.push(issue("warning", "layout-overlap", `Extended outputs ${extended[first].output} and ${extended[second].output} overlap.`, [extended[first].output, extended[second].output]));
        }
    }
    if (extended.length > 1) {
        for (const rule of extended) {
            if (!extended.some(other => other !== rule && isAdjacent(rule, other, 1)))
                warnings.push(issue("warning", "layout-island", `Output ${rule.output} is separated from the rest of the extended layout.`, [rule.output]));
        }
    }

    return { valid: errors.length === 0, errors, warnings };
}
