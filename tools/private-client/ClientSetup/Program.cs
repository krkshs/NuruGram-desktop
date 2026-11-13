using System.Diagnostics;
using System.Net;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

if (args.Length is < 3 or > 4)
    throw new ArgumentException("Usage: ClientSetup original-Telegram.exe server-public.pem output-Telegram.exe [server-ipv4]");
var source = Path.GetFullPath(args[0]);
var target = Path.GetFullPath(args[2]);
if (string.Equals(source, target, StringComparison.OrdinalIgnoreCase))
    throw new ArgumentException("Use a separate client copy");
var endpoint = args.Length == 4 ? args[3] : "31.77.17.214";
if (!IPAddress.TryParse(endpoint, out var addressIp) || addressIp.AddressFamily != AddressFamily.InterNetwork)
    throw new ArgumentException("An IPv4 address is required");
endpoint = addressIp.ToString();
var bytes = File.ReadAllBytes(source);
if (bytes.Length < 2 || bytes[0] != 'M' || bytes[1] != 'Z')
    throw new InvalidDataException("Expected Windows PE");
var originalHash = Convert.ToHexString(SHA256.HashData(bytes));
using var rsa = RSA.Create();
rsa.ImportFromPem(File.ReadAllText(args[1]));
var publicText = rsa.ExportRSAPublicKeyPem().Replace("\r\n", "\n");
if (rsa.KeySize != 2048) throw new InvalidDataException("A 2048-bit server public key is required");
var latin = Encoding.Latin1.GetString(bytes);
var keys = Regex.Matches(latin, @"-----BEGIN RSA PUBLIC KEY-----\n[A-Za-z0-9+/=\n]+-----END RSA PUBLIC KEY-----");
if (keys.Count == 0) throw new InvalidDataException("No embedded Telegram RSA public keys found; this build needs source compilation");
foreach (Match match in keys)
{
    var replacement = Encoding.ASCII.GetBytes(publicText);
    if (replacement.Length != match.Length)
        throw new InvalidDataException("Public key length mismatch; refusing binary patch");
    replacement.CopyTo(bytes, match.Index);
}
var addresses = new[] { "149.154.175.50", "149.154.167.51", "95.161.76.100", "149.154.175.100", "149.154.167.91", "149.154.171.5", "149.154.175.10", "149.154.167.40", "149.154.175.117" };
var replacements = 0;
foreach (var address in addresses)
{
    var needle = Encoding.ASCII.GetBytes(address + "\0");
    var position = 0;
    while (true)
    {
        var at = bytes.AsSpan(position).IndexOf(needle);
        if (at < 0) break;
        at += position;
        if (endpoint.Length >= needle.Length)
            throw new InvalidDataException($"Endpoint does not fit the slot for {address}");
        Array.Clear(bytes, at, needle.Length - 1);
        Encoding.ASCII.GetBytes(endpoint).CopyTo(bytes, at);
        replacements++;
        position = at + needle.Length;
    }
}
if (replacements < 5) throw new InvalidDataException("Expected built-in DC IPv4 table was not found");
var ipv6 = "::ffff:" + endpoint;
var ipv6Matches = Regex.Matches(latin, @"2001:0[0-9a-f:]{33}");
foreach (Match match in ipv6Matches)
{
    if (ipv6.Length > match.Length) throw new InvalidDataException("IPv6 endpoint does not fit");
    Array.Clear(bytes, match.Index, match.Length);
    Encoding.ASCII.GetBytes(ipv6).CopyTo(bytes, match.Index);
}
Directory.CreateDirectory(Path.GetDirectoryName(target)!);
File.WriteAllBytes(target, bytes);
var version = FileVersionInfo.GetVersionInfo(source).ProductVersion ?? "unknown";
var manifest = new
{
    OriginalSha256 = originalHash,
    PatchedSha256 = Convert.ToHexString(SHA256.HashData(bytes)),
    PublicKeySha256 = Convert.ToHexString(SHA256.HashData(rsa.ExportRSAPublicKey())),
    RsaKeysReplaced = keys.Count,
    Ipv4AddressesReplaced = replacements,
    Ipv6AddressesReplaced = ipv6Matches.Count,
    Endpoint = endpoint + ":443",
    Client = "Official Telegram Desktop " + version,
    Repository = "https://github.com/krkshs/NuruGram-desktop"
};
File.WriteAllText(target + ".manifest.json", JsonSerializer.Serialize(manifest, new JsonSerializerOptions { WriteIndented = true }));
Console.WriteLine($"Prepared private client: RSA keys={keys.Count}, IPv4={replacements}, IPv6={ipv6Matches.Count}, server={endpoint}:443");
