#if defined _studiomdl_included
  #endinput
#endif

#define _studiomdl_included

#define EVENT_CLIENT 5000
#define STUDIO_LOOPING 0x0001

enum studiohdr {
  studiohdr_id,
  studiohdr_version,
  // studiohdr_name[64],
  studiohdr_length,
  Float:studiohdr_eyeposition[3],
  // Float:studiohdr_mins[3],
  // Float:studiohdr_maxs[3],
  // Float:studiohdr_bbmins[3],
  // Float:studiohdr_bbmaxs[3],
  studiohdr_flags,
  studiohdr_numbones,
  studiohdr_boneindex,
  studiohdr_numbonecontrollers,
  studiohdr_bonecontrollerindex,
  studiohdr_numhitboxes,
  studiohdr_hitboxindex,
  studiohdr_numseq,
  studiohdr_seqindex,
  studiohdr_numseqgroups,
  studiohdr_seqgroupindex,
  // studiohdr_numtextures,
  // studiohdr_textureindex,
  // studiohdr_texturedataindex,
  studiohdr_numskinref,
  studiohdr_numskinfamilies,
  studiohdr_skinindex,
  studiohdr_numbodyparts,
  studiohdr_bodypartindex,
  studiohdr_numattachments,
  studiohdr_attachmentindex,
  // studiohdr_soundtable,
  // studiohdr_soundindex,
  // studiohdr_soundgroups,
  // studiohdr_soundgroupindex,
  // studiohdr_numtransitions,
  // studiohdr_transitionindex,
};

enum mstudioevent {
  mstudioevent_frame,
  mstudioevent_event,
  mstudioevent_type,
  mstudioevent_options[64]
};

enum mstudioseqdesc {
  // mstudioseqdesc_label[32],
  Float:mstudioseqdesc_fps,
  mstudioseqdesc_flags,
  mstudioseqdesc_activity,
  mstudioseqdesc_actweight,
  mstudioseqdesc_numevents,
  mstudioseqdesc_eventindex,
  mstudioseqdesc_numframes,
  // mstudioseqdesc_numpivots,
  // mstudioseqdesc_pivotindex,
  // mstudioseqdesc_motiontype,
  // mstudioseqdesc_motionbone,
  Float:mstudioseqdesc_linearmovement[3],
  // mstudioseqdesc_automoveposindex,
  // mstudioseqdesc_automoveangleindex,
  // Float:mstudioseqdesc_bbmin[3],
  // Float:mstudioseqdesc_bbmax[3],
  mstudioseqdesc_numblends,
  mstudioseqdesc_animindex,
  // mstudioseqdesc_blendtype[2],
  // Float:mstudioseqdesc_blendstart[2],
  // Float:mstudioseqdesc_blendend[2],
  // mstudioseqdesc_blendparent,
  mstudioseqdesc_seqgroup,
  // mstudioseqdesc_entrynode,
  // mstudioseqdesc_exitnode,
  // mstudioseqdesc_nodeflags,
  // mstudioseqdesc_nextseq
};

stock studiomdl_open(const path[]) {
  new file = fopen(path, "rb", true, "GAME");

  if (!file) {
    file = fopen(path, "rb", true, "DEFAULTGAME");
  }

  return file;
}

stock studiomdl_close(&file) {
  fclose(file);
}

stock studiomdl_read_header(const &file, data[studiohdr]) {
  fseek(file, BLOCK_INT, SEEK_CUR);
  fread(file, data[studiohdr_version], BLOCK_INT);
  fseek(file, BLOCK_CHAR * 64, SEEK_CUR);
  fread(file, data[studiohdr_length], BLOCK_INT);
  fread_blocks(file, data[studiohdr_eyeposition], 3, BLOCK_INT);
  fseek(file, BLOCK_INT * 3 * 4, SEEK_CUR);
  fread(file, data[studiohdr_flags], BLOCK_INT);
  fread(file, data[studiohdr_numbones], BLOCK_INT);
  fread(file, data[studiohdr_boneindex], BLOCK_INT);
  fread(file, data[studiohdr_numbonecontrollers], BLOCK_INT);
  fread(file, data[studiohdr_bonecontrollerindex], BLOCK_INT);
  fread(file, data[studiohdr_numhitboxes], BLOCK_INT);
  fread(file, data[studiohdr_hitboxindex], BLOCK_INT);
  fread(file, data[studiohdr_numseq], BLOCK_INT);
  fread(file, data[studiohdr_seqindex], BLOCK_INT);
  fread(file, data[studiohdr_numseqgroups], BLOCK_INT);
  fread(file, data[studiohdr_seqgroupindex], BLOCK_INT);
  fseek(file, BLOCK_INT * 3, SEEK_CUR);
  fread(file, data[studiohdr_numskinref], BLOCK_INT);
  fread(file, data[studiohdr_numskinfamilies], BLOCK_INT);
  fread(file, data[studiohdr_skinindex], BLOCK_INT);
  fread(file, data[studiohdr_numbodyparts], BLOCK_INT);
  fread(file, data[studiohdr_bodypartindex], BLOCK_INT);
  fread(file, data[studiohdr_numattachments], BLOCK_INT);
  fread(file, data[studiohdr_attachmentindex], BLOCK_INT);
  fseek(file, BLOCK_INT * 6, SEEK_CUR);
}

stock studiomdl_read_sequence(const &file, data[mstudioseqdesc]) {
  fseek(file, BLOCK_CHAR * 32, SEEK_CUR);
  fread(file, data[mstudioseqdesc_fps], BLOCK_INT);
  fread(file, data[mstudioseqdesc_flags], BLOCK_INT);
  fread(file, data[mstudioseqdesc_activity], BLOCK_INT);
  fread(file, data[mstudioseqdesc_actweight], BLOCK_INT);
  fread(file, data[mstudioseqdesc_numevents], BLOCK_INT);
  fread(file, data[mstudioseqdesc_eventindex], BLOCK_INT);
  fread(file, data[mstudioseqdesc_numframes], BLOCK_INT);
  fseek(file, BLOCK_INT * 4, SEEK_CUR);
  fread_blocks(file, data[mstudioseqdesc_linearmovement], 3, BLOCK_INT);
  fseek(file, (BLOCK_INT * 2) + (BLOCK_INT * 3 * 2), SEEK_CUR);
  fread(file, data[mstudioseqdesc_numblends], BLOCK_INT);
  fread(file, data[mstudioseqdesc_animindex], BLOCK_INT);
  fseek(file, (BLOCK_INT * 2 * 3) + BLOCK_INT, SEEK_CUR);
  fread(file, data[mstudioseqdesc_seqgroup], BLOCK_INT);
  fseek(file, (BLOCK_INT * 4), SEEK_CUR);
}

stock studiomdl_read_event(const &file, data[mstudioevent]) {
  fread(file, data[mstudioevent_frame], BLOCK_INT);
  fread(file, data[mstudioevent_event], BLOCK_INT);
  fread(file, data[mstudioevent_type], BLOCK_INT);
  fread_blocks(file, data[mstudioevent_options], sizeof(data[mstudioevent_options]), BLOCK_CHAR);
}
