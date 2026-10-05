namespace DuoLauncher;

/// <summary>Small strict SemVer comparer; release versions never rely on file names.</summary>
public readonly record struct SemVersion(int Major, int Minor, int Patch, string? PreRelease = null) : IComparable<SemVersion>
{
    public static SemVersion Parse(string value)
    {
        if (!TryParse(value, out var version)) throw new FormatException($"Invalid semantic version: {value}");
        return version;
    }

    public static bool TryParse(string? value, out SemVersion version)
    {
        version = default;
        if (string.IsNullOrWhiteSpace(value)) return false;
        var parts = value.Trim().Split('+', 2)[0].Split('-', 2);
        var core = parts[0].Split('.');
        if (core.Length != 3 || !int.TryParse(core[0], out var major) || !int.TryParse(core[1], out var minor) || !int.TryParse(core[2], out var patch) || major < 0 || minor < 0 || patch < 0) return false;
        var pre = parts.Length == 2 ? parts[1] : null;
        if (pre is { Length: 0 }) return false;
        version = new SemVersion(major, minor, patch, pre);
        return true;
    }

    public int CompareTo(SemVersion other)
    {
        var core = Major.CompareTo(other.Major);
        if (core == 0) core = Minor.CompareTo(other.Minor);
        if (core == 0) core = Patch.CompareTo(other.Patch);
        if (core != 0) return core;
        if (PreRelease is null) return other.PreRelease is null ? 0 : 1;
        if (other.PreRelease is null) return -1;
        var left = PreRelease.Split('.'); var right = other.PreRelease.Split('.');
        for (var i = 0; i < Math.Min(left.Length, right.Length); i++)
        {
            if (left[i] == right[i]) continue;
            var ln = int.TryParse(left[i], out var li); var rn = int.TryParse(right[i], out var ri);
            if (ln && rn) return li.CompareTo(ri);
            if (ln) return -1;
            if (rn) return 1;
            return string.CompareOrdinal(left[i], right[i]);
        }
        return left.Length.CompareTo(right.Length);
    }

    public override string ToString() => $"{Major}.{Minor}.{Patch}{(PreRelease is null ? "" : "-" + PreRelease)}";
}
