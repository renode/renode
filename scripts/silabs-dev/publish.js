const fs = require('fs')
const path = require('path')
const { execFileSync } = require('child_process')
const renode = require('./renode')

const rootDir = path.join(__dirname, '..', '..')

// When making slt package, we add these files into the "linux_portable" package, so that they are available in the slt package as well.
const addOnFiles = [
  {
    src: 'apack.json',
    dest: 'apack.json',
  },
  {
    src: 'tools/packaging/linux/icons/128x128/apps/renode.png',
    dest: 'renode.png',
  },
]

const artifactory = {
  url: 'https://artifactory.silabs.net/artifactory',
  rootDir: 'sw-arch-generic-tools/renode',
}

function prepDist() {
  // This function should unzip a zip file that is in dist/ directory. It should unzip it right into that directory.
  const distDir = path.join(rootDir, 'dist')
  const files = fs.readdirSync(distDir)
  const zipFile = files.find((f) => f.endsWith('.zip'))
  if (!zipFile) {
    throw new Error(`No zip file found in dist directory: ${distDir}`)
  }
  const zipPath = path.join(distDir, zipFile)
  console.log(`📦 Unzipping ${zipPath}...`)
  execFileSync('unzip', ['-o', zipPath, '-d', distDir], {
    cwd: rootDir,
    stdio: 'inherit',
    shell: false,
  })
}

function unzipDist() {
  // Unzip dist.zip from the repo root (created by dist-zip) back into place.
  const zipPath = path.join(rootDir, 'dist.zip')
  if (!fs.existsSync(zipPath)) {
    throw new Error(`dist.zip does not exist: ${zipPath}`)
  }
  console.log(`📦 Unzipping ${zipPath}...`)
  execFileSync('unzip', ['-o', zipPath], {
    cwd: rootDir,
    stdio: 'inherit',
    shell: false,
  })
}

function createDist(skipFetchLibraries = false) {
  console.log('🦄 Creating distribution site:')

  const distDir = path.join(rootDir, 'dist')
  fs.mkdirSync(distDir, { recursive: true })

  // First we need to run `./build.sh -t`
  console.log('  🔸 building linux portable package...')
  var args = ['-t']
  if (skipFetchLibraries) {
    args.push('--skip-fetch')
    args.push('--net')
  }
  execFileSync('./build.sh', args, {
    cwd: rootDir,
    stdio: 'inherit',
    shell: false,
  })

  // Then we need to detect the actual name of the file.
  // It is put into output/packages/ directory and has a name like renode-*-linux-portable.tar.gz
  const outputDir = path.join(rootDir, 'output', 'packages')
  const files = fs.readdirSync(outputDir)
  const renodePackageName = files.find(
    (f) => f.startsWith('renode-') && f.endsWith('linux-portable.tar.gz'),
  )
  if (!renodePackageName) {
    throw new Error(`Could not find renode package file in ${outputDir}`)
  }

  const versionTag = renode.silabsRenodeVersion()
  const silabsPackageName = `renode-${versionTag}-linux-x86.zip`
  const silabsPackagePath = path.join(distDir, silabsPackageName)

  // What we have to do here now is:
  //  1.) tar -xvzf the renodePackageName into a temporary directory
  //  2.) Copy the apack.json file from the root of repo into that temporary directory.
  //  3.) Zip up the contents of the temporary directory into silabsPackagePath.
  const tmpDir = fs.mkdtempSync(path.join(rootDir, 'tmp-'))
  try {
    execFileSync(
      'tar',
      ['-xvzf', path.join(outputDir, renodePackageName), '-C', tmpDir],
      {
        cwd: rootDir,
        stdio: 'inherit',
        shell: false,
      },
    )
    // Tarballed create a toplevel directory. Create a variable "innerTmpDir" that points to that directory.
    const innerTmpDir = fs
      .readdirSync(tmpDir)
      .find((f) => fs.statSync(path.join(tmpDir, f)).isDirectory())

    // Iterate over addonFiles and add them to innerTmpDir
    for (const file of addOnFiles) {
      const srcPath = path.join(rootDir, file.src)
      const destPath = path.join(tmpDir, innerTmpDir, file.dest)
      fs.copyFileSync(srcPath, destPath)
    }

    execFileSync('zip', ['-r', silabsPackagePath, '.'], {
      cwd: path.join(tmpDir, innerTmpDir),
      stdio: 'inherit',
      shell: false,
    })
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true })
  }
  console.log(`  🔸 created: ${path.basename(silabsPackagePath)}`)
  let siteJson = createSiteJson(
    distDir,
    versionTag,
    path.basename(silabsPackagePath),
    '.', // zipDir: root directory in the archive
  )
  console.log(`  🔸 created: ${path.basename(siteJson)}`)
}

function buildStamp() {
  // Return the YYYYMMDD-HHMMSS timestamp of the current time.

  let now = new Date()
  let year = now.getUTCFullYear()
  let month = String(now.getUTCMonth() + 1).padStart(2, '0')
  let day = String(now.getUTCDate()).padStart(2, '0')
  let hours = String(now.getUTCHours()).padStart(2, '0')
  let minutes = String(now.getUTCMinutes()).padStart(2, '0')
  let seconds = String(now.getUTCSeconds()).padStart(2, '0')

  return `${year}${month}${day}-${hours}${minutes}${seconds}`
}

function createSiteJson(distDir, version, zipName, zipDir) {
  let siteJsonPath = path.join(distDir, 'site.json')
  let s = {
    id: 'renode',
    description:
      'Renode is a development framework for simulating embedded systems.',
    featureLevel: 3,
    packages: [
      {
        id: 'renode',
        name: 'Renode Simulator',
        os: 'linux',
        arch: 'amd64',
        dir: zipDir,
        path: '.',
        version: version,
        build: buildStamp(),
        url: zipName,
        forceClean: true,
      },
    ],
  }
  fs.writeFileSync(siteJsonPath, JSON.stringify(s, null, 2), 'utf8')
  return siteJsonPath
}

function zipDist() {
  const distDir = path.join(rootDir, 'dist')
  const zipPath = path.join(rootDir, 'dist.zip')
  if (!fs.existsSync(distDir)) {
    throw new Error(`dist directory does not exist: ${distDir}`)
  }

  // Remove any existing archive so zip does not append to a stale file.
  fs.rmSync(zipPath, { force: true })

  console.log(`📦 Zipping ${distDir} to ${zipPath}...`)
  execFileSync('zip', ['-r', zipPath, 'dist'], {
    cwd: rootDir,
    stdio: 'inherit',
    shell: false,
  })
  console.log(`  🔸 created: ${path.basename(zipPath)}`)
}

function uploadDist(pathToPublish) {
  console.log('🚀 Uploading distribution to artifactory...')
  const distDir = path.join(rootDir, 'dist')
  if (!fs.existsSync(distDir)) {
    throw new Error(`dist directory does not exist: ${distDir}`)
  }

  execFileSync(
    `jf`,
    ['rt', 'delete', artifactory.rootDir + pathToPublish, '--quiet'],
    {
      cwd: distDir,
      stdio: 'inherit',
      shell: false,
    },
  )

  execFileSync(
    `jf`,
    ['rt', 'upload', '*', artifactory.rootDir + pathToPublish],
    {
      cwd: distDir,
      stdio: 'inherit',
      shell: false,
    },
  )
}

exports.uploadDist = uploadDist
exports.createDist = createDist
exports.prepDist = prepDist
exports.zipDist = zipDist
exports.unzipDist = unzipDist
