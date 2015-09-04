using System;
using System.IO;
using Newtonsoft.Json;
using Nito.AsyncEx;

namespace WowheadParser
{
    internal class Program
    {
        public static void Main(string[] args)
        {
            var cmd = new CmdOptions();
            if (!CommandLine.Parser.Default.ParseArguments(args, cmd))
                return;

            var parser = new Parser(cmd.FromLanguage, cmd.ToLanguage);
            var quests = AsyncContext.Run(() => parser.ParseAsync());

            File.WriteAllText(cmd.OutputFileName, JsonConvert.SerializeObject(quests, Formatting.Indented));

            if (cmd.ResultsFileName != null)
            {
                File.WriteAllText(cmd.ResultsFileName, JsonConvert.SerializeObject(parser.Results, Formatting.Indented));
            }

            Console.WriteLine("Parsing was completed...");
            Console.ReadLine();
        }
    }
}
