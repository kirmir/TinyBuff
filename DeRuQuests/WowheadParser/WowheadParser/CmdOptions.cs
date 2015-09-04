using CommandLine;

namespace WowheadParser
{
    internal class CmdOptions
    {
        [Option('f', "from", Required = true, HelpText = "The original language to find the translation.")]
        public string FromLanguage { get; set; }

        [Option('t', "to", Required = true, HelpText = "The target language to find the translation.")]
        public string ToLanguage { get; set; }
    }
}
