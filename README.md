# Overview

This is a tool to keep git integration branches up to date.  It takes a base
branch (e.g. master), an integration branch (e.g. pu) to update, and a topic
branch queue.  The integration branch will be reset to the base branch (or some
intermediate point, if possible), and each topic branch in the queue will be
merged in, one-by-one.  After each branch is merged, make will be called to
verify the project still builds.  If a branch does not merge cleanly (and rerere
can't fix it), or if make does not complete succesfully, the branch will be
excluded.  The result will be a newly constructed integration branch built off
of the specified base, with all of the topic branches from the queue merged
(except those which don't merge cleanly or which break the build).
