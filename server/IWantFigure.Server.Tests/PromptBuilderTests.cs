using IWantFigure.Server.Contracts;
using IWantFigure.Server.Imaging;
using IWantFigure.Server.Providers;

namespace IWantFigure.Server.Tests;

public class PromptBuilderTests
{
    private static readonly PreparedImage Image = new(new byte[] { 1 }, "image/jpeg", 1456, 971);

    private static string Build(AnalyzeHints? hints, string locale = "en") =>
        PromptBuilder.BuildUserText(new AnalyzeRequest { Locale = locale, Hints = hints }, Image, "COORDS");

    [Fact]
    public void Oversized_prize_size_array_is_cut_to_three_values_and_prompt_stays_small()
    {
        double[] huge = Enumerable.Range(0, 200_000).Select(i => (double)(i % 1000)).ToArray();

        string text = Build(new AnalyzeHints { PrizeSizeMm = huge });

        Assert.True(text.Length < 1000, $"prompt is {text.Length} chars");
        // first three finite in-range values: 0 is dropped (< 1 mm), so 1, 2, 3
        Assert.Contains("prize_size_mm [w, d, h]: [1, 2, 3]", text);
    }

    [Fact]
    public void Prize_size_values_outside_1_to_2000_mm_and_non_finite_are_dropped()
    {
        string text = Build(new AnalyzeHints { PrizeSizeMm = new[] { double.NaN, -5, 0.5, 120, double.PositiveInfinity, 5000, 90, 160, 170 } });

        Assert.Contains("prize_size_mm [w, d, h]: [120, 90, 160]", text);
        Assert.DoesNotContain("170", text);
        Assert.DoesNotContain("5000", text);
    }

    [Fact]
    public void Prize_size_with_no_usable_values_is_omitted_entirely()
    {
        string text = Build(new AnalyzeHints { PrizeSizeMm = new[] { -1.0, 99999 } });

        Assert.DoesNotContain("prize_size_mm", text);
        Assert.DoesNotContain("Hints from the player", text);
    }

    [Theory]
    [InlineData(2, "claw_count: 2")]
    [InlineData(99, "claw_count: 5")]
    [InlineData(int.MaxValue, "claw_count: 5")]
    [InlineData(-3, "claw_count: 0")]
    public void Claw_count_is_clamped_to_0_5(int input, string expected)
    {
        string text = Build(new AnalyzeHints { ClawCount = input });

        Assert.Contains(expected, text);
    }

    [Fact]
    public void Long_text_hints_are_truncated_and_flattened_to_one_line()
    {
        string notes = string.Concat(Enumerable.Repeat("line\n", 400)); // 2000 chars, many newlines

        string text = Build(new AnalyzeHints { Notes = notes, MachineFamily = new string('x', 1200) });

        string notesLine = text.Split('\n').Single(l => l.StartsWith("- notes:", StringComparison.Ordinal));
        Assert.True(notesLine.Length <= "- notes: ".Length + PromptBuilder.MaxHintTextLength + 3);
        string familyLine = text.Split('\n').Single(l => l.StartsWith("- machine_family:", StringComparison.Ordinal));
        Assert.EndsWith("...", familyLine);
        Assert.True(familyLine.Length <= "- machine_family: ".Length + PromptBuilder.MaxHintTextLength + 3);
    }

    [Theory]
    [InlineData("ko", "Korean")]
    [InlineData("ja", "Japanese")]
    [InlineData("en", "English")]
    [InlineData("fr", "English")]
    [InlineData(null, "English")]
    public void Locale_maps_to_a_language_name(string? locale, string expected)
    {
        Assert.Contains(expected, Build(null, locale!));
        Assert.Contains("1456x971", Build(null, locale!));
        Assert.Contains("COORDS", Build(null, locale!));
    }
}
