CSIconView is a Cocoa class that implements a Finder-style icon view, complete with drag & drop, support for renaming items, support for the different state icons, coloured labels, and even support for multiple icon sizes in the same icon view.

It was started back in 2005, and has languished on my disk unfinished ever since, so yesterday at NSConference I decided to tidy it up and stick it somewhere where others could get at it.

It's worth noting that back in 2005, the Cocoa frameworks and indeed Objective-C itself didn't have some of the things we take for granted today. It's quite possible that I wouldn't write this code in exactly the same way now, but I think it's valuable to have a published example of a fairly complete and fairly complex custom control.

One final note: this code isn't that well tested, and in places it isn't as polished as I would want it if I were using it in my app.

New: there's now a sample app that shows some basic usage of CSIconView to display a list of attendees at NSConference 2009 and 2010.