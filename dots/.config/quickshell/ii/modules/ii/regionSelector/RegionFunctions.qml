pragma Singleton
import Quickshell

Singleton {
    id: root

    function intersectionOverUnion(regionA, regionB) {
        // region: { at: [x, y], size: [w, h] }
        const ax1 = regionA.at[0], ay1 = regionA.at[1];
        const ax2 = ax1 + regionA.size[0], ay2 = ay1 + regionA.size[1];
        const bx1 = regionB.at[0], by1 = regionB.at[1];
        const bx2 = bx1 + regionB.size[0], by2 = by1 + regionB.size[1];

        const interX1 = Math.max(ax1, bx1);
        const interY1 = Math.max(ay1, by1);
        const interX2 = Math.min(ax2, bx2);
        const interY2 = Math.min(ay2, by2);

        const interArea = Math.max(0, interX2 - interX1) * Math.max(0, interY2 - interY1);
        const areaA = (ax2 - ax1) * (ay2 - ay1);
        const areaB = (bx2 - bx1) * (by2 - by1);
        const unionArea = areaA + areaB - interArea;

        return unionArea > 0 ? interArea / unionArea : 0;
    }

    function regionArea(region) {
        return region.size[0] * region.size[1];
    }

    function isValidRegion(region) {
        return !!region && region.size[0] > 0 && region.size[1] > 0;
    }

    function regionContainsPoint(region, x, y) {
        return region.at[0] <= x && x <= region.at[0] + region.size[0]
            && region.at[1] <= y && y <= region.at[1] + region.size[1];
    }

    function filterWindowRegionsByLayers(windowRegions, layerRegions) {
        return windowRegions.filter(windowRegion => {
            for (let i = 0; i < layerRegions.length; ++i) {
                if (intersectionOverUnion(windowRegion, layerRegions[i]) > 0)
                    return false;
            }
            return true;
        });
    }

    // Collects every candidate (from both sources) that contains the given
    // point, tagged with where it came from. Degenerate candidates are
    // rejected here so callers never have to think about them again.
    function collectCandidatesAt(x, y, layerRegions, windowRegions) {
        const candidates = [];
        for (const region of layerRegions) {
            if (isValidRegion(region) && regionContainsPoint(region, x, y))
                candidates.push({ source: "layer", region });
        }
        for (const region of windowRegions) {
            if (isValidRegion(region) && regionContainsPoint(region, x, y))
                candidates.push({ source: "window", region });
        }
        return candidates;
    }

    // Deterministically picks a single winning candidate for the cursor
    // position (x, y).
    //
    //  1. A layer/popup candidate always wins over a window: it's exact
    //     compositor geometry. If several layers overlap (nested popups),
    //     the smallest (most specific) one wins.
    //  2. Otherwise, the window under the cursor wins. Among overlapping
    //     windows, the smallest wins as a heuristic for "topmost"/foreground.
    //  3. If nothing qualifies, there is no target.
    function selectTargetCandidate(x, y, layerRegions, windowRegions) {
        const candidates = collectCandidatesAt(x, y, layerRegions, windowRegions);

        const smallest = list => list.reduce((best, c) =>
            (!best || regionArea(c.region) < regionArea(best.region)) ? c : best, null);

        const layers = candidates.filter(c => c.source === "layer");
        if (layers.length > 0) return { winner: smallest(layers), candidates };

        const windows = candidates.filter(c => c.source === "window");
        if (windows.length > 0) return { winner: smallest(windows), candidates };

        return { winner: null, candidates };
    }
}
