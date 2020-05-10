const core = require('@actions/core');
const exec = require('@actions/exec');

async function run() {
    try {
        const env = process.env;
        const workspace = env.GITHUB_WORKSPACE;
        for (const home in [env.HOME, env.FLUTTER_HOME]) {
            core.addPath(`${home}/.pub-cache/bin`);
        }
        await core.group(
            'Installing pana',
            async () => await exec.exec('pub', ['global', 'activate', 'pana'])
        );
        const options = { cwd: `${workspace}/app` };
        await core.group(
            'Getting dependencies',
            async () => await exec.exec('pub', ['get'], options)
        );
        await exec.exec('dart', ['bin/main.dart'], options);
    }
    catch (error) {
        core.setFailed(error.message);
    }
}

run()