/*
   This file is part of MusicBrainz, the open internet music database.
   Copyright (c) 2005 Stefan Kestenholz (keschte)
   Copyright (C) 2010 MetaBrainz Foundation

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

*/

MB.GuessCase = (MB.GuessCase) ? MB.GuessCase : {};
MB.GuessCase.Handler = (MB.GuessCase.Handler) ? MB.GuessCase.Handler : {};

/**
 * Track specific GuessCase functionality
 **/
MB.GuessCase.Handler.Track = function () {
    var self = MB.GuessCase.Handler.Base ();

    // ----------------------------------------------------------------------------
    // member functions
    // ---------------------------------------------------------------------------

    /**
     * Guess the trackname given in string is, and
     * returns the guessed name.
     *
     * @param	is		the inputstring
     * @returns os		the processed string
     **/
    self.process = function(is) {
	is = gc.mode.stripInformationToOmit(is);
	is = gc.mode.preProcessCommons(is);
	is = gc.mode.preProcessTitles(is);
	var words = gc.i.splitWordsAndPunctuation(is);
	words = gc.mode.prepExtraTitleInfo(words);
	gc.o.init();
	gc.i.init(is, words);
	while (!gc.i.isIndexAtEnd()) {
	    self.processWord();
	}
	var os = gc.o.getOutput();
	os = gc.mode.runPostProcess(os);
	os = gc.mode.runFinalChecks(os);
	return os;
    };

    /**
     * Detect if UntitledTrackStyle and DataTrackStyle needs
     * to be applied.
     *
     * - data [track]			-> [data track]
     * - silence|silent [track]	-> [silence]
     * - untitled [track]		-> [untitled]
     * - unknown|bonus [track]	-> [unknown]
     **/
    self.checkSpecialCase = function(is) {
	if (is) {
	    if (!gc.re.TRACK_DATATRACK) {
		// data tracks
		gc.re.TRACK_DATATRACK = /^([\(\[]?\s*data(\s+track)?\s*[\)\]]?$)/i;
		// silence
		gc.re.TRACK_SILENCE = /^([\(\[]?\s*(silen(t|ce)|blank)(\s+track)?\s*[\)\]]?)$/i;
		// untitled
		gc.re.TRACK_UNTITLED = /^([\(\[]?\s*untitled(\s+track)?\s*[\)\]]?)$/i;
		// unknown
		gc.re.TRACK_UNKNOWN = /^([\(\[]?\s*(unknown|bonus|hidden)(\s+track)?\s*[\)\]]?)$/i;
		// any number of question marks
		gc.re.TRACK_MYSTERY = /^\?+$/i;
	    }
	    if (is.match(gc.re.TRACK_DATATRACK)) {
		return self.SPECIALCASE_DATA_TRACK;

	    } else if (is.match(gc.re.TRACK_SILENCE)) {
		return self.SPECIALCASE_SILENCE;

	    } else if (is.match(gc.re.TRACK_UNTITLED)) {
		return self.SPECIALCASE_UNTITLED;

	    } else if (is.match(gc.re.TRACK_UNKNOWN)) {
		return self.SPECIALCASE_UNKNOWN;

	    } else if (is.match(gc.re.TRACK_MYSTERY)) {
		return self.SPECIALCASE_UNKNOWN;
	    }
	}
	return self.NOT_A_SPECIALCASE;
    };


    /**
     * Delegate function which handles words not handled
     * in the common word handlers.
     *
     * - Handles FeaturingArtistStyle
     * - Handles VersusStyle
     * - Handles VolumeNumberStyle
     * - Handles PartNumberStyle
     *
     **/
    self.doWord = function() {

        if (self.doIgnoreWords ()) {
        } else if (self.doFeaturingArtistStyle()) {
        } else if (self.doVersusStyle()) {
	} else if (self.doVolumeNumberStyle()) {
	} else if (self.doPartNumberStyle()) {
	} else if (gc.mode.doWord()) {
	} else {
	    if (gc.i.matchCurrentWord(/7in/i)) {
		gc.o.appendSpaceIfNeeded();
		gc.o.appendWord('7"');
		gc.f.resetContext();
		gc.f.spaceNextWord = false;
		gc.f.forceCaps = false;
	    } else if (gc.i.matchCurrentWord(/12in/i)) {
		gc.o.appendSpaceIfNeeded();
		gc.o.appendWord('12"');
		gc.f.resetContext();
		gc.f.spaceNextWord = false;
		gc.f.forceCaps = false;
	    } else {
		// handle other cases (e.g. normal words)
		gc.o.appendSpaceIfNeeded();
		gc.i.capitalizeCurrentWord();

		gc.o.appendCurrentWord();
		gc.f.resetContext();
		gc.f.spaceNextWord = true;
		gc.f.forceCaps = false;
	    }
	}
	gc.f.number = false;
	return null;
    };

    return self;
};