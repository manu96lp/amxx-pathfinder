#if defined _pathfinder_included
  #endinput
#endif
#define _pathfinder_included

const MAX_NODES = 128;
const MAX_NODE_LINKS = 3;

/**
 * Gets a path from "point A" to "point B"
 *
 * @note Path is a series of linked nodes
 * @note In case of success, passed array must be destroyed after use
 *
 * @param flStart 		Start from this point
 * @param flEnd 		End on this point
 * @param aPath 		Path array
 *
 * @return          	Array of size 3 (vector)
 * @error           	false
 */
native bool:GeneratePath( const Float:flStart[ 3 ], const Float:flEnd[ 3 ], &Array:aPath );

/**
 * Gets the number of created nodes
 *
 * @return 	   Number of nodes
 */
native GetNodeCount( );

/**
 * Gets origin of a node
 *
 * @param iNode 			Node to retrieve information from
 * @param flOrigin 			Node origin
 *
 * @noreturn
 */
native GetNodeOrigin( const iNode, Float:flOrigin[ ] );

/**
 * Gets link information of a node
 *
 * @param iNode 			Node to retrieve information from
 * @param iLinkId 			Node link index
 * @param iLinkNode 		Link node id
 * @param iLinkDistance 	Link distance
 *
 * @noreturn
 */
native GetNodeLink( const iNode, const iLinkId, const iLinkNode, const Float:iLinkDistance );

/**
 * Gets all information about a node
 *
 * @param iNode 	Node to retrieve link count from
 *
 * @return 		Number of links
 */
native GetNodeLinkCount( const iNode );