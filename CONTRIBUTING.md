# How to contribute?

If you are reading this, chances are you want to contribute to the Renode project, and that is already great news.

Note that you must sign a Contributor License Agreement (CLA) in order to contribute to this project.

Please read the short manual below where we provide some simple guidelines for a good cooperation experience.

## Issues

Issues in the Renode project are tracked in the [GitHub issues system](https://github.com/antmicro/renode/issues).

We also use an internal issue tracker, so it is possible that some referenced issues are not publicly available.

Please create an issue even if you plan to fix it (instead of creating a merge request directly - see below).

If you are reporting a bug, the best way to ensure it's reproducible is by using Renode's [Issue reproduction template](https://github.com/renode/renode-issue-reproduction-template).
Use this repo template to create a setup that reproduces your use cases and fails a test.
This will ensure we're able to understand the bug you're experiencing and will help us react faster.

If you'd like to file a feature request, then just carefully describe what you need - the more background and precise suggestions you provide, the higher the chance that someone will be able to implement it.

If, for some reason, it's impossible to create a reproduction repo for your issue, please ensure you provide all of the following:

* the platform you are using (MacOS, Windows, Linux, what distro/version?)
* the Renode version you are using
* the exact platform you are trying to run (`.resc` and `.repl` files or links to those if you are using default ones)
* preferably, the source code of your binary with build instructions - or at least a binary.

We know in some cases users are not able to share the full source code of the binary they are trying to run.
In this case you may try to isolate the problem to some smaller example which is not problematic to share, or at least share a binary.

Otherwise you can of course contact us at [support@renode.io](mailto:support@renode.io) and provide what is needed under an NDA.

## Pull requests

If you plan to fix an issue by yourself, you should use the [GitHub pull requests mechanism](https://github.com/antmicro/renode/pulls).
To do that, you need to:

* create a fork of our repository on your account (if you haven't done it already)
* create a branch based on the current `master` branch with the following name:

  `NUMBER_OF_TICKET-short_name_of_the_issue`, for example `1234-invalid_instruction_wfi`
* write and commit your code (see sections below)
* if your pull request is about to fix an issue or add a new feature, use Renode's [Issue reproduction template](https://github.com/renode/renode-issue-reproduction-template) and try to prepare two branches - one that fails a test and one that includes your fix and passes the same test
* create a pull request to our Renode repository with the proposed fix.

Your merge request will then be reviewed by the Renode team, and potentially a discussion on GitHub will ensue.

We might ask you to do some fixes or write a test for your change, but this is only meant to keep code quality high(er).

If this is your first contribution to Renode, you will also be asked to sign our Contributor License Agreement, which you can do directly from within the Pull Request in question.

After you sign the CLA and our team performs a final review of your code, it will be merged to the Renode master branch.

## Committing

### Guidelines

We recommend small commits. 
Note that while small commits can always be squashed together, dividing commits is not that straightforward.

For example if for the issue to be fixed you need to correct two classes without changing their public interface, do it in two separate commits.
Also if the change as a whole is big, it is easier to review it afterwards if it is divided into parts similar to the way the original author introduced the changes.
If you change some names and behaviour in the same commit, it is hard to tell which changes apply where.

If you are fixing some formatting issue, please take care to separate these changes from any logic-related commits.
You don't have to split formatting of different files into different commits, however, formatting changes are best done simultaneously for coherence.

It is vital to have all the code compiling without errors after each commit - this is useful for bisecting.

### Commit messages

Here is a proposed format of the commit message:

```
[#1234] optional-tag: Short description of a commit

If you feel that the commit needs a bit more explanation than
a short description you can put all your thoughts here (after
a blank line).
```

`#1234` is obviously the number of the GitHub issue that describes the problem you're trying to fix.
As we use an internal issue tracker, you may observe that some issue numbers (over #5000) are not pointing to any GitHub issue.

The short description is just a short sentence describing changes introduced by a commit.
If you have problems to formulate a single sentence (because the commit makes a lot of changes) than perhaps you should consider splitting it into several independent commits (as noted above).
We usually write these descriptions in a form of a sentence, in imperative mood, starting with a capitalized letter.

You can add an optional tag word before the commit message - it is especially useful if you have a series of commits related to the same topic (e.g. changes in one peripheral model).

The long description is not obligatory, but nice to have.
There is no word limit here, but we all should be reasonable.
Discussions and long analyses should be placed in the GitHub issue system.

## Code formatting and quality

As we use Monodevelop for development, we rely on its formatting engine.
Each project and solution contains settings for the Monodevelop formatter.
If you use another editor, you may read the `.csproj` file and apply these rules by hand, as they are written in a readable format.

Please do not introduce formatting that is strictly inconsistent with other files.

Do not use `regions` to separate categories of methods/fields in your classes.
We usually try to keep the classes' API at the top, and the gory stuff below.

The rule of thumb is:

* public before protected before private
* static before instance
* constructor before method before property before field before constant
* all inner types at the end.

As this list does not cover all possible options, you may be asked to fix something during review.
