/obj/item/soulstone
	name = "soulstone shard"
	icon = 'icons/obj/wizard.dmi'
	icon_state = "soulstone"
	item_state = "electronic"
	lefthand_file = 'icons/mob/inhands/misc/devices_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/misc/devices_righthand.dmi'
	layer = HIGH_OBJ_LAYER
	desc = "A fragment of the legendary treasure known simply as the 'Soul Stone'. The shard still flickers with a fraction of the full artefact's power."
	w_class = WEIGHT_CLASS_TINY
	slot_flags = INV_SLOTBIT_BELT
	var/usability = FALSE

	var/old_shard = FALSE
	var/spent = FALSE

/obj/item/soulstone/proc/was_used()
	if(old_shard)
		spent = TRUE
		name = "dull [name]"
		desc = "A fragment of the legendary treasure known simply as \
			the 'Soul Stone'. The shard lies still, dull and lifeless; \
			whatever spark it once held long extinguished."

/obj/item/soulstone/anybody
	usability = TRUE

/obj/item/soulstone/anybody/chaplain
	name = "mysterious old shard"
	old_shard = TRUE

/obj/item/soulstone/pickup(mob/living/user)
	..()
	if(!iscultist(user, TRUE) && !iswizard(user) && !usability)
		to_chat(user, span_danger("An overwhelming feeling of dread comes over you as you pick up the soulstone. It would be wise to be rid of this quickly."))

/obj/item/soulstone/examine(mob/user)
	. = ..()
	if(usability || iscultist(user, TRUE) || iswizard(user) || isobserver(user))
		if (old_shard)
			. += span_cult("A soulstone, used to capture a soul, either from dead humans or from freed shades.")
		else
			. += span_cult("A soulstone, used to capture souls, either from unconscious or sleeping humans or from freed shades.")
		. += span_cult("The captured soul can be placed into a construct shell to produce a construct, or released from the stone as a shade.")
		if(spent)
			. += span_cult("This shard is spent; it is now just a creepy rock.")

/obj/item/soulstone/Destroy() //Stops the shade from being qdel'd immediately and their ghost being sent back to the arrival shuttle.
	for(var/mob/living/simple_animal/shade/A in src)
		A.death()
	return ..()

//////////////////////////////Capturing////////////////////////////////////////////////////////

/obj/item/soulstone/attack(mob/living/carbon/human/M, mob/living/user)
	if(!iscultist(user, TRUE) && !iswizard(user) && !usability)
		user.Unconscious(100)
		to_chat(user, span_userdanger("Your body is wracked with debilitating pain!"))
		return
	if(spent)
		to_chat(user, span_warning("There is no power left in the shard."))
		return
	if(!ishuman(M))//If target is not a human.
		return ..()
	if(iscultist(M))
		if(iscultist(user))
			to_chat(user, span_cultlarge("\"Come now, do not capture your bretheren's soul.\""))
			return
	log_combat(user, M, "captured [M.name]'s soul", src)
	transfer_soul("VICTIM", M, user)

///////////////////Options for using captured souls///////////////////////////////////////

/obj/item/soulstone/attack_self(mob/living/user)
	if(!in_range(src, user))
		return
	if(!iscultist(user, TRUE) && !iswizard(user) && !usability)
		user.Unconscious(100)
		to_chat(user, span_userdanger("Your body is wracked with debilitating pain!"))
		return
	release_shades(user)

/obj/item/soulstone/proc/release_shades(mob/user)
	for(var/mob/living/simple_animal/shade/A in src)
		A.status_flags &= ~GODMODE
		A.forceMove(get_turf(user))
		A.mobility_flags = MOBILITY_FLAGS_DEFAULT
		A.cancel_camera()
		icon_state = "soulstone"
		name = initial(name)
		if(iswizard(user) || usability)
			to_chat(A, "<b>You have been released from your prison, but you are still bound to [user.real_name]'s will. Help [user.p_them()] succeed in [user.p_their()] goals at all costs.</b>")
		else if(iscultist(user))
			to_chat(A, "<b>You have been released from your prison, but you are still bound to the cult's will. Help them succeed in their goals at all costs.</b>")
		was_used()

///////////////////////////Transferring to constructs/////////////////////////////////////////////////////
/obj/structure/constructshell
	name = "empty shell"
	icon = 'icons/obj/wizard.dmi'
	icon_state = "construct-cult"
	desc = "A wicked machine used by those skilled in magical arts. It is inactive."

/obj/structure/constructshell/examine(mob/user)
	. = ..()
	if(iscultist(user, TRUE) || iswizard(user) || user.stat == DEAD)
		. += span_cult("A construct shell, used to house bound souls from a soulstone.")
		. += span_cult("Placing a soulstone with a soul into this shell allows you to produce your choice of the following:")
		. += "<span class='cult'>An <b>Artificer</b>, which can produce <b>more shells and soulstones</b>, as well as fortifications.</span>"
		. += "<span class='cult'>A <b>Wraith</b>, which does high damage and can jaunt through walls, though it is quite fragile.</span>"
		. += "<span class='cult'>A <b>Juggernaut</b>, which is very hard to kill and can produce temporary walls, but is slow.</span>"

/obj/structure/constructshell/attackby(obj/item/O, mob/user, params)
	if(istype(O, /obj/item/soulstone))
		var/obj/item/soulstone/SS = O
		if(!iscultist(user, TRUE) && !iswizard(user) && !SS.usability)
			to_chat(user, span_danger("An overwhelming feeling of dread comes over you as you attempt to place the soulstone into the shell. It would be wise to be rid of this quickly."))
			user.Dizzy(30)
			return
		SS.transfer_soul("CONSTRUCT",src,user)
		SS.was_used()
	else
		return ..()

////////////////////////////Proc for moving soul in and out off stone//////////////////////////////////////


/obj/item/soulstone/proc/transfer_soul(choice as text, target, mob/user)
	switch(choice)
		if("FORCE")
			if(!iscarbon(target))		//TODO: Add sacrifice stoning for non-organics, just because you have no body doesnt mean you dont have a soul
				return FALSE
			if(contents.len)
				return FALSE
			var/mob/living/carbon/T = target
			if(T.client != null)
				for(var/obj/item/W in T)
					T.dropItemToGround(W)
				init_shade(T, user)
				return TRUE
			else
				to_chat(user, "<span class='userdanger'>Capture failed!</span>: The soul has already fled its mortal frame. You attempt to bring it back...")
				return getCultGhost(T,user)

		if("VICTIM")
			var/mob/living/carbon/human/T = target
			var/datum/antagonist/cult/C = user.mind.has_antag_datum(/datum/antagonist/cult,TRUE)
			if(C && C.cult_team?.is_sacrifice_target(T.mind))
				if(iscultist(user))
					to_chat(user, "<span class='cult'><b>\"This soul is mine.</b></span> <span class='cultlarge'>SACRIFICE THEM!\"</span>")
				else
					to_chat(user, span_danger("The soulstone seems to reject this soul."))
				return FALSE
			if(contents.len)
				to_chat(user, "<span class='userdanger'>Capture failed!</span>: The soulstone is full! Free an existing soul to make room.")
			else
				if((!old_shard && T.stat != CONSCIOUS) || (old_shard && T.stat == DEAD))
					if(T.client == null)
						to_chat(user, "<span class='userdanger'>Capture failed!</span>: The soul has already fled its mortal frame. You attempt to bring it back...")
						getCultGhost(T,user)
					else
						for(var/obj/item/W in T)
							T.dropItemToGround(W)
						init_shade(T, user, vic = 1)
						qdel(T)
				else
					to_chat(user, "<span class='userdanger'>Capture failed!</span>: Kill or maim the victim first!")

		if("SHADE")
			var/mob/living/simple_animal/shade/T = target
			if(contents.len)
				to_chat(user, "<span class='userdanger'>Capture failed!</span>: The soulstone is full! Free an existing soul to make room.")
			else
				T.forceMove(src) //put shade in stone
				T.status_flags |= GODMODE
				T.mobility_flags = NONE
				T.health = T.maxHealth
				icon_state = "soulstone2"
				name = "soulstone: Shade of [T.real_name]"
				to_chat(T, span_notice("Your soul has been captured by the soulstone. Its arcane energies are reknitting your ethereal form."))
				if(user != T)
					to_chat(user, "<span class='info'><b>Capture successful!</b>:</span> [T.real_name]'s soul has been captured and stored within the soulstone.")

		if("CONSTRUCT")
			var/obj/structure/constructshell/T = target
			var/mob/living/simple_animal/shade/A = locate() in src
			if(A)
				var/construct_class = alert(user, "Please choose which type of construct you wish to create.",,"Juggernaut","Wraith","Artificer")
				if(!T || !T.loc)
					return
				switch(construct_class)
					if("Juggernaut")
						makeNewConstruct(/mob/living/simple_animal/hostile/construct/armored, A, user, 0, T.loc)

					if("Wraith")
						makeNewConstruct(/mob/living/simple_animal/hostile/construct/wraith, A, user, 0, T.loc)

					if("Artificer")
						if(iscultist(user) || iswizard(user))
							makeNewConstruct(/mob/living/simple_animal/hostile/construct/builder, A, user, 0, T.loc)

						else
							makeNewConstruct(/mob/living/simple_animal/hostile/construct/builder/noncult, A, user, 0, T.loc)
				for(var/datum/mind/B in SSticker.mode.cult)
					if(B == A.mind)
						SSticker.mode.cult -= A.mind
						SSticker.mode.update_cult_icons_removed(A.mind)
				qdel(T)
				qdel(src)
			else
				to_chat(user, "<span class='userdanger'>Creation failed!</span>: The soul stone is empty! Go kill someone!")


/proc/makeNewConstruct(mob/living/simple_animal/hostile/construct/ctype, mob/target, mob/stoner = null, cultoverride = 0, loc_override = null)
	var/mob/living/simple_animal/hostile/construct/newstruct = new ctype((loc_override) ? (loc_override) : (get_turf(target)))
	if(stoner)
		newstruct.faction |= "[REF(stoner)]"
		newstruct.master = stoner
		var/datum/action/innate/seek_master/SM = new()
		SM.Grant(newstruct)
	target.transfer_ckey(newstruct)
	var/obj/screen/alert/bloodsense/BS
	if(newstruct.mind && ((stoner && iscultist(stoner)) || cultoverride) && SSticker && SSticker.mode)
		SSticker.mode.add_cultist(newstruct.mind, 0)
	if(iscultist(stoner) || cultoverride)
		to_chat(newstruct, "<b>You are still bound to serve the cult[stoner ? " and [stoner]":""], follow [stoner ? stoner.p_their() : "their"] orders and help [stoner ? stoner.p_them() : "them"] complete [stoner ? stoner.p_their() : "their"] goals at all costs.</b>")
	else if(stoner)
		to_chat(newstruct, "<b>You are still bound to serve your creator, [stoner], follow [stoner.p_their()] orders and help [stoner.p_them()] complete [stoner.p_their()] goals at all costs.</b>")
	newstruct.clear_alert("bloodsense")
	BS = newstruct.throw_alert("bloodsense", /obj/screen/alert/bloodsense)
	if(BS)
		BS.Cviewer = newstruct
	newstruct.cancel_camera()


/obj/item/soulstone/proc/init_shade(mob/living/carbon/human/T, mob/user, vic = 0)
	new /obj/effect/decal/remains/human(T.loc) //Spawns a skeleton
	T.stop_sound_channel(CHANNEL_HEARTBEAT)
	T.invisibility = INVISIBILITY_ABSTRACT
	T.dust_animation()
	QDEL_IN(T, 5)
	var/mob/living/simple_animal/shade/S = new /mob/living/simple_animal/shade(src)
	S.status_flags |= GODMODE			//So they won't die inside the stone somehow
	S.mobility_flags = NONE				//Can't move out of the soul stone
	S.name = "Shade of [T.real_name]"
	S.real_name = "Shade of [T.real_name]"
	T.transfer_ckey(S)
	S.copy_languages(T, LANGUAGE_MIND)//Copies the old mobs languages into the new mob holder.
	S.copy_languages(user, LANGUAGE_MASTER)
	S.update_atom_languages()
	grant_all_languages(FALSE, FALSE, TRUE)	//Grants omnitongue
	if(user)
		S.faction |= "[REF(user)]" //Add the master as a faction, allowing inter-mob cooperation
	if(user && iscultist(user))
		SSticker.mode.add_cultist(S.mind, 0)
	S.cancel_camera()
	name = "soulstone: Shade of [T.real_name]"
	icon_state = "soulstone2"
	if(user && (iswizard(user) || usability))
		to_chat(S, "Your soul has been captured! You are now bound to [user.real_name]'s will. Help [user.p_them()] succeed in [user.p_their()] goals at all costs.")
	else if(user && iscultist(user))
		to_chat(S, "Your soul has been captured! You are now bound to the cult's will. Help them succeed in their goals at all costs.")
	if(vic && user)
		to_chat(user, "<span class='info'><b>Capture successful!</b>:</span> [T.real_name]'s soul has been ripped from [T.p_their()] body and stored within the soul stone.")


/obj/item/soulstone/proc/getCultGhost(mob/living/carbon/human/T, mob/U)
	var/mob/dead/observer/chosen_ghost

	for(var/mob/dead/observer/ghost in GLOB.player_list) //We put them back in their body
		if(ghost.mind && ghost.mind.current == T && ghost.client)
			chosen_ghost = ghost
			break

	if(!chosen_ghost)	//Failing that, we grab a ghost
		var/list/consenting_candidates = pollGhostCandidates("Would you like to play as a Shade?", "Cultist", null, ROLE_CULTIST, poll_time = 50)
		if(consenting_candidates.len)
			chosen_ghost = pick(consenting_candidates)
	if(!T)
		return FALSE
	if(!chosen_ghost)
		to_chat(U, span_danger("There were no spirits willing to become a shade."))
		return FALSE
	if(contents.len) //If they used the soulstone on someone else in the meantime
		return FALSE
	T.ckey = chosen_ghost.ckey
	for(var/obj/item/W in T)
		T.dropItemToGround(W)
	init_shade(T, U)
	qdel(T)
	return TRUE
