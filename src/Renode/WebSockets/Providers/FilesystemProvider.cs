//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Net.Http;
using System.Threading.Tasks;

using Antmicro.Renode.Utilities;

using Newtonsoft.Json;

namespace Antmicro.Renode.WebSockets.Providers
{
    public static class HttpClientExtensions
    {
        public static void DownloadFile(this HttpClient client, Uri address, WriteFilePath fileName)
        {
            client.DownloadFileAsync(address, fileName).GetAwaiter().GetResult();
        }

        public static async Task DownloadFileAsync(this HttpClient client, Uri address, WriteFilePath fileName)
        {
            var sourceStream = await client.GetStreamAsync(address);
            using(var destinationStream = new FileStream(fileName, FileMode.CreateNew))
            {
                await sourceStream.CopyToAsync(destinationStream);
            }
        }
    }

    public class FilesystemProvider : IWebSocketAPIProvider
    {
        public FilesystemProvider()
        {
        }

        public bool Start(WebSocketAPISharedData sharedData)
        {
            SharedData = sharedData;
            return true;
        }

        [WebSocketAPIAction("fs/list", "1.5.0")]
        private WebSocketAPIResponse ListFilesAction(List<string> args)
        {
            try
            {
                var fullPath = ResolvePath(args[0]);
                var filesResult = Directory
                    .GetFiles(fullPath)?
                    .Select(f => PathInfo(f));

                var dirResult = Directory
                    .GetDirectories(fullPath)?
                    .Select(d => PathInfo(d));

                var result = filesResult.Concat(dirResult);

                return WebSocketAPIUtils.CreateActionResponse(result);
            }
            catch(Exception)
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse();
            }
        }

        [WebSocketAPIAction("fs/mkdir", "1.5.0")]
        private WebSocketAPIResponse MakeDirectoryAction(List<string> args)
        {
            try
            {
                var fullPath = ResolvePath(args[0]);
                Directory.CreateDirectory(fullPath);
                return WebSocketAPIUtils.CreateEmptyActionResponse();
            }
            catch(Exception e)
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse(e.Message);
            }
        }

        [WebSocketAPIAction("fs/stat", "1.5.0")]
        private WebSocketAPIResponse FileInfoAction(List<string> args)
        {
            try
            {
                var fullPath = ResolvePath(args[0]);

                if(File.Exists(fullPath))
                {
                    var fileInfo = new FileInfo(fullPath);
                    var fileAttr = File.GetAttributes(fullPath);

                    var ctime = new DateTimeOffset(fileInfo.CreationTime);
                    var mtime = new DateTimeOffset(fileInfo.LastWriteTime);

                    var result = new StatActionResponseDto
                    {
                        Success = true,
                        Size = fileInfo.Length,
                        IsFile = true,
                        CTime = Convert.ToSingle(ctime.ToUnixTimeSeconds()),
                        MTime = Convert.ToSingle(mtime.ToUnixTimeSeconds())
                    };

                    return WebSocketAPIUtils.CreateActionResponse(result);
                }
                else if(Directory.Exists(fullPath))
                {
                    var directoryInfo = new DirectoryInfo(fullPath);

                    var ctime = new DateTimeOffset(directoryInfo.CreationTime);
                    var mtime = new DateTimeOffset(directoryInfo.LastWriteTime);

                    var result = new StatActionResponseDto
                    {
                        Success = true,
                        Size = -1,
                        IsFile = false,
                        CTime = Convert.ToSingle(ctime.ToUnixTimeSeconds()),
                        MTime = Convert.ToSingle(mtime.ToUnixTimeSeconds())
                    };

                    return WebSocketAPIUtils.CreateActionResponse(result);
                }
                else
                {
                    return WebSocketAPIUtils.CreateEmptyActionResponse($"{fullPath} does not exist");
                }
            }
            catch(Exception e)
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse(e.Message);
            }
        }

        [WebSocketAPIAction("fs/dwnl", "1.5.0")]
        private WebSocketAPIResponse DownloadAction(List<string> args)
        {
            try
            {
                var fullPath = ResolvePath(args[0]);
                var data = File.ReadAllBytes(fullPath);
                var result = Convert.ToBase64String(data);

                return WebSocketAPIUtils.CreateActionResponse(result);
            }
            catch(Exception e)
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse(e.Message);
            }
        }

        [WebSocketAPIAction("fs/upld", "1.5.0")]
        private WebSocketAPIResponse UploadAction(List<string> args, string data)
        {
            try
            {
                var bytes = Convert.FromBase64String(data);
                var path = ResolvePath(args[0]);
                var directory = Path.GetDirectoryName(path);
                Directory.CreateDirectory(directory);
                File.WriteAllBytes(path, bytes);

                return WebSocketAPIUtils.CreateActionResponse(new PathActionResponseDto
                {
                    Success = true,
                    Path = path
                });
            }
            catch(Exception e)
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse(e.Message);
            }
        }

        [WebSocketAPIAction("fs/remove", "1.5.0")]
        private WebSocketAPIResponse RemoveAction(List<string> args)
        {
            try
            {
                var fullPath = ResolvePath(args[0]);
                File.Delete(fullPath);

                var result = new PathActionResponseDto
                {
                    Success = true,
                    Path = fullPath
                };

                return WebSocketAPIUtils.CreateActionResponse(result);
            }
            catch(Exception e)
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse(e.Message);
            }
        }

        [WebSocketAPIAction("fs/move", "1.5.0")]
        private WebSocketAPIResponse MoveAction(List<string> args)
        {
            try
            {
                var oldPath = ResolvePath(args[0]);
                var newPath = ResolvePath(args[1]);

                File.Move(oldPath, newPath);

                var result = new MoveActionResponseDto
                {
                    Success = true,
                    From = oldPath,
                    To = newPath
                };

                return WebSocketAPIUtils.CreateActionResponse(result);
            }
            catch(Exception e)
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse(e.Message);
            }
        }

        [WebSocketAPIAction("fs/copy", "1.5.0")]
        private WebSocketAPIResponse CopyAction(List<string> args)
        {
            try
            {
                var filePath = ResolvePath(args[0]);
                var newFilePath = ResolvePath(args[1]);
                File.Copy(filePath, newFilePath);

                var result = new MoveActionResponseDto
                {
                    Success = true,
                    From = filePath,
                    To = newFilePath
                };

                return WebSocketAPIUtils.CreateActionResponse(result);
            }
            catch(Exception e)
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse(e.Message);
            }
        }

        [WebSocketAPIAction("fs/fetch", "1.5.0")]
        private WebSocketAPIResponse FetchAction(List<string> args)
        {
            try
            {
                var uri = new Uri(args[0]);
                var fileName = System.IO.Path.GetFileName(uri.LocalPath);
                var newFilePath = ResolvePath(fileName);

                using(var client = new HttpClient())
                {
                    client.DownloadFile(uri, newFilePath);
                }

                var result = new PathActionResponseDto
                {
                    Success = true,
                    Path = newFilePath
                };

                return WebSocketAPIUtils.CreateActionResponse(result);
            }
            catch(Exception e)
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse(e.Message);
            }
        }

        [WebSocketAPIAction("fs/zip", "1.5.0")]
        private WebSocketAPIResponse ZipAction(List<string> args)
        {
            try
            {
                var uri = new Uri(args[0]);
                var tempZipPath = ResolvePath("temp.zip");

                using(var client = new HttpClient())
                {
                    client.DownloadFile(uri, tempZipPath);
                }

                ZipFile.ExtractToDirectory(tempZipPath, SharedData.Cwd.Value, true);

                var result = new PathActionResponseDto
                {
                    Success = true,
                    Path = SharedData.Cwd.Value
                };

                return WebSocketAPIUtils.CreateActionResponse(result);
            }
            catch(Exception e)
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse(e.Message);
            }
        }

        [WebSocketAPIAction("tweak/socket", "1.5.0")]
        private WebSocketAPIResponse TweakSocketAction(List<string> _)
        {
            var result = new StatusActionResponseDto
            {
                Success = true
            };

            return WebSocketAPIUtils.CreateActionResponse(result);
        }

        private string ResolvePath(string path, string basePath = null)
        {
            if(basePath == null)
            {
                basePath = SharedData.Cwd.Value;
            }

            if(Path.IsPathRooted(path))
            {
                var parts = path.Split(Path.DirectorySeparatorChar);
                var pathWithoutRoot = parts.Skip(1).Aggregate((p1, p2) => $"{p1}/{p2}");
                return Path.Combine(basePath, pathWithoutRoot);
            }

            return Path.Combine(basePath, path);
        }

        private PathInfoDto PathInfo(string path)
        {
            var fileAttr = File.GetAttributes(path);

            return new PathInfoDto
            {
                Name = Path.GetFileName(path),
                IsFile = !fileAttr.HasFlag(FileAttributes.Directory),
                IsLink = fileAttr.HasFlag(FileAttributes.ReparsePoint)
            };
        }

        private WebSocketAPISharedData SharedData;

        private class StatusActionResponseDto
        {
            [JsonProperty("success")]
            public bool Success;
        }

        private class PathActionResponseDto
        {
            [JsonProperty("success")]
            public bool Success;
            [JsonProperty("path")]
            public string Path;
        }

        private class PathInfoDto
        {
            [JsonProperty("name")]
            public string Name;
            [JsonProperty("isfile")]
            public bool IsFile;
            [JsonProperty("islink")]
            public bool IsLink;
        }

        private class MoveActionResponseDto
        {
            [JsonProperty("success")]
            public bool Success;
            [JsonProperty("from")]
            public string From;
            [JsonProperty("to")]
            public string To;
        }

        private class StatActionResponseDto
        {
            [JsonProperty("success")]
            public bool Success;
            [JsonProperty("size")]
            public long Size;
            [JsonProperty("isfile")]
            public bool IsFile;
            [JsonProperty("ctime")]
            public float CTime;
            [JsonProperty("mtime")]
            public float MTime;
        }
    }
}