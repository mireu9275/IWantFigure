namespace IWantFigure.Server.Analysis;

/// <summary>
/// The provider answered, but the text was not JSON or could not be normalized into a
/// schema-valid document. Retried once by AnalysisService, then surfaced as HTTP 502.
/// </summary>
public sealed class AnalysisFormatException : Exception
{
    public AnalysisFormatException(string message, Exception? inner = null) : base(message, inner)
    {
    }
}
