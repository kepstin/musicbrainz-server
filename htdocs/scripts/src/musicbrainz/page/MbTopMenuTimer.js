/*----------------------------------------------------------------------------\
|                              Musicbrainz.org                                |
|                 Copyright (c) 2005 Stefan Kestenholz (g0llum)               |
|-----------------------------------------------------------------------------|
| This software is provided "as is", without warranty of any kind, express or |
| implied, including  but not limited  to the warranties of  merchantability, |
| fitness for a particular purpose and noninfringement. In no event shall the |
| authors or  copyright  holders be  liable for any claim,  damages or  other |
| liability, whether  in an  action of  contract, tort  or otherwise, arising |
| from,  out of  or in  connection with  the software or  the  use  or  other |
| dealings in the software.                                                   |
| - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - |
| GPL - The GNU General Public License    http://www.gnu.org/licenses/gpl.txt |
| Permits anyone the right to use and modify the software without limitations |
| as long as proper  credits are given  and the original  and modified source |
| code are included. Requires  that the final product, software derivate from |
| the original  source or any  software  utilizing a GPL  component, such  as |
| this, is also licensed under the GPL license.                               |
|-----------------------------------------------------------------------------|
| 2005-11-10 | First version                                                  |
\----------------------------------------------------------------------------*/


/**
 * MbTopMenuTimer is the class used to maintain the state of the
 * topmenu timeout events.
 *
 * @constructor
 */
function MbTopMenuTimer() {
	mb.log.enter("MbTopMenuTimer", "__constructor");

	// ----------------------------------------------------------------------------
	// register class/global id
	// ---------------------------------------------------------------------------
	this.CN = "MbTopMenuTimer";
	this.GID = "mb.topmenu.timer"

	// ----------------------------------------------------------------------------
	// member variables
	// ---------------------------------------------------------------------------

	/**
	 * Timeout reference for menu close-time,
	 * @type Number
	 **/
	this.closeTimer = null;

	/**
	 * Timeout reference for menu open-time,
	 * @type Number
	 **/
	this.openTimer = null;

	/**
	 * The name of the function that is called after a timeout
	 * is triggered,
	 * @type String
	 **/
	this.closeFunc = "mb.topmenu.hideDisplayedDropDown()";

	/**

	 * @type Number
	 **/
	this.activateTime = 150; // ms

	/**
	 * The time that elapses until the dropdown is closed after
	 * leaving a mainmenu item. this timeout is restarted upon
	 * re-entry into another mainmenu item.
	 * @type Number
	 **/
	this.closeMenuTime = 350; // ms

	/**
	 * The time that elapses until the dropdown is closed after
	 * leaving a dropdown item. this timeout gets reset upon
	 * re-entry into another dropdown.
	 * @type Number
	 **/
	this.closeSubmenuTime = 350; // ms

	// ----------------------------------------------------------------------------
	// member functions
	// ---------------------------------------------------------------------------

	/**
	 * Clear the timeouts
	 */
	this.clear = function() {
		clearTimeout(this.openTimer);
		clearTimeout(this.closeTimer);
	};

	/**
	 */
	this.activateMenuItem = function(id, flag) {
		mb.topmenu.mouseOver(id, flag);
		this.clear();
		this.openTimer = setTimeout("mb.topmenu.activateMenuItem('"+id+"', "+flag+");", this.activateTime);
	};

	/**
	 * Reset timers when mouse enters a submenu
	 */
	this.hasEnteredSubMenu = function() {
		this.clear();
	};

	/**
	 * Set the timer to close the dropdown when the mouse has left a submenu
	 */
	this.hasLeftSubMenu = function() {
		clearTimeout(this.closeTimer);
		this.closeTimer = setTimeout(this.closeFunc, this.closeSubmenuTime);
	};

	// exit constructor
	mb.log.exit();
}