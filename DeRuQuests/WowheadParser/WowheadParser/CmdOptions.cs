using CommandLine;
using CommandLine.Text;

namespace WowheadParser
{
    internal class CmdOptions
    {
        [Option('f', "from", Required = true, HelpText = "The original language (en, ru, de) to find the translation.")]
        public string FromLanguage { get; set; }

        [Option('t', "to", Required = true, HelpText = "The target language (en, ru, de) to find the translation.")]
        public string ToLanguage { get; set; }

        [Option('o', "out", Required = true, HelpText = "The output file name for parsed data.")]
        public string OutputFileName { get; set; }

        [Option('r', "res", Required = false, HelpText = "The output file name for parsing results.")]
        public string ResultsFileName { get; set; }

        [HelpOption]
        public string GetUsage()
        {
            return HelpText.AutoBuild(this, x => HelpText.DefaultParsingErrorsHandler(this, x));
        }
    }
}
